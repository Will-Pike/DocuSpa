#!/bin/bash

# DocuSpa Update Script
# Safely update the application with zero-downtime deployment

set -e

# Configuration
APP_DIR="/opt/docuspa"
BACKUP_DIR="/opt/docuspa-backups"
SERVICE_NAME="docuspa"
USER="docuspa"
LOG_FILE="/var/log/docuspa/update.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

echo -e "${BLUE}🚀 DocuSpa Update Script${NC}"
echo "=========================="

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}❌ This script should not be run as root${NC}"
    echo "Please run as a regular user with sudo privileges"
    exit 1
fi

# Create backup directory if it doesn't exist
sudo mkdir -p "$BACKUP_DIR"
sudo chown "$USER:$USER" "$BACKUP_DIR"

# Generate backup filename with timestamp
BACKUP_NAME="docuspa-backup-$(date +%Y%m%d-%H%M%S)"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

echo -e "${YELLOW}📦 Creating backup...${NC}"
log "Starting backup creation: $BACKUP_NAME"

# Create backup
sudo -u "$USER" cp -r "$APP_DIR" "$BACKUP_PATH"
log "Backup created: $BACKUP_PATH"
echo -e "${GREEN}✅ Backup created: $BACKUP_PATH${NC}"

# Change to application directory
cd "$APP_DIR"

echo -e "${YELLOW}📡 Checking for updates...${NC}"

# Fetch latest changes
sudo -u "$USER" git fetch origin

# Check if there are updates
LOCAL=$(sudo -u "$USER" git rev-parse HEAD)
REMOTE=$(sudo -u "$USER" git rev-parse origin/main)

if [ "$LOCAL" = "$REMOTE" ]; then
    echo -e "${GREEN}✅ Application is already up to date${NC}"
    log "No updates available. Local: $LOCAL, Remote: $REMOTE"
    exit 0
fi

echo -e "${YELLOW}📥 Updates available. Pulling changes...${NC}"
log "Updates found. Local: $LOCAL, Remote: $REMOTE"

# Store current commit for rollback
PREVIOUS_COMMIT=$LOCAL

# Pull latest changes
sudo -u "$USER" git pull origin main
log "Git pull completed successfully"

# Check if requirements.txt changed
if sudo -u "$USER" git diff --name-only "$PREVIOUS_COMMIT" HEAD | grep -q "requirements.txt"; then
    echo -e "${YELLOW}📦 Requirements changed. Updating dependencies...${NC}"
    log "Requirements.txt changed, updating dependencies"
    
    # Activate virtual environment and update dependencies
    sudo -u "$USER" bash -c "source venv/bin/activate && pip install -r requirements.txt"
    log "Dependencies updated successfully"
else
    echo -e "${GREEN}✅ No dependency changes detected${NC}"
    log "No dependency changes detected"
fi

# Check if database migrations are needed
if [ -d "migrations" ] && [ -n "$(find migrations -name '*.py' -newer "$BACKUP_PATH" 2>/dev/null)" ]; then
    echo -e "${YELLOW}🗄️ Running database migrations...${NC}"
    log "Database migrations detected, running migrations"
    
    # Run migrations (adjust command as needed)
    sudo -u "$USER" bash -c "source venv/bin/activate && python -c 'from app.database import Base, engine; Base.metadata.create_all(bind=engine)'"
    log "Database migrations completed"
fi

# Test the application before restarting
echo -e "${YELLOW}🧪 Testing application...${NC}"
log "Running application tests"

# Quick syntax check
sudo -u "$USER" bash -c "source venv/bin/activate && python -m py_compile main.py"

# Test import
sudo -u "$USER" bash -c "cd $APP_DIR && source venv/bin/activate && python -c 'import main; print(\"Import test passed\")'"
log "Application tests passed"

echo -e "${GREEN}✅ Application tests passed${NC}"

# Restart the service
echo -e "${YELLOW}🔄 Restarting DocuSpa service...${NC}"
log "Restarting DocuSpa service"

sudo systemctl restart "$SERVICE_NAME"

# Wait for service to start
echo -e "${YELLOW}⏳ Waiting for service to start...${NC}"
sleep 10

# Check if service is running
if sudo systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Service restarted successfully${NC}"
    log "Service restart successful"
else
    echo -e "${RED}❌ Service failed to start. Rolling back...${NC}"
    log "Service restart failed, initiating rollback"
    
    # Rollback
    rollback_update "$PREVIOUS_COMMIT"
    exit 1
fi

# Health check
echo -e "${YELLOW}🏥 Running health check...${NC}"
sleep 5

# Simple health check
HEALTH_CHECK=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health 2>/dev/null || echo "000")

if [ "$HEALTH_CHECK" = "200" ]; then
    echo -e "${GREEN}✅ Health check passed${NC}"
    log "Health check passed - HTTP $HEALTH_CHECK"
else
    echo -e "${RED}❌ Health check failed. Rolling back...${NC}"
    log "Health check failed - HTTP $HEALTH_CHECK, initiating rollback"
    
    # Rollback
    rollback_update "$PREVIOUS_COMMIT"
    exit 1
fi

# Clean up old backups (keep last 5)
echo -e "${YELLOW}🧹 Cleaning up old backups...${NC}"
cd "$BACKUP_DIR"
ls -t | tail -n +6 | xargs -r rm -rf
log "Old backup cleanup completed"

# Update completed successfully
NEW_COMMIT=$(sudo -u "$USER" git -C "$APP_DIR" rev-parse HEAD)
echo ""
echo -e "${GREEN}🎉 Update completed successfully!${NC}"
echo -e "${GREEN}✅ Updated from $PREVIOUS_COMMIT to $NEW_COMMIT${NC}"
echo -e "${GREEN}✅ Backup available at: $BACKUP_PATH${NC}"

log "Update completed successfully. Updated to: $NEW_COMMIT"

# Display changelog
echo ""
echo -e "${BLUE}📝 Changelog:${NC}"
sudo -u "$USER" git -C "$APP_DIR" log --oneline "$PREVIOUS_COMMIT..HEAD"

exit 0

# Rollback function
rollback_update() {
    local commit_to_rollback_to=$1
    
    echo -e "${YELLOW}🔄 Rolling back to previous version...${NC}"
    log "Starting rollback to commit: $commit_to_rollback_to"
    
    # Checkout previous commit
    sudo -u "$USER" git -C "$APP_DIR" checkout "$commit_to_rollback_to"
    
    # Restart service
    sudo systemctl restart "$SERVICE_NAME"
    
    # Wait and check
    sleep 10
    
    if sudo systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Rollback completed successfully${NC}"
        log "Rollback completed successfully"
    else
        echo -e "${RED}❌ Rollback failed. Manual intervention required.${NC}"
        log "Rollback failed, manual intervention required"
        echo -e "${RED}💡 Try restoring from backup: $BACKUP_PATH${NC}"
    fi
}