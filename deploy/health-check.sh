#!/bin/bash

# DocuSpa Health Check Script
# Use this to monitor your application's health

set -e

# Configuration
APP_URL="http://localhost:8000"
HEALTH_ENDPOINT="/health"
LOG_FILE="/var/log/docuspa/health-check.log"
MAX_LOG_SIZE=10485760  # 10MB in bytes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to log with timestamp
log_with_timestamp() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to rotate logs if they get too large
rotate_logs() {
    if [ -f "$LOG_FILE" ] && [ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt $MAX_LOG_SIZE ]; then
        mv "$LOG_FILE" "${LOG_FILE}.old"
        touch "$LOG_FILE"
        chown docuspa:docuspa "$LOG_FILE" 2>/dev/null || true
        log_with_timestamp "Log file rotated due to size limit"
    fi
}

# Function to check application health
check_app_health() {
    local response=$(curl -s -w "%{http_code}" -o /dev/null --max-time 10 "${APP_URL}${HEALTH_ENDPOINT}" 2>/dev/null || echo "000")
    
    if [ "$response" = "200" ]; then
        echo -e "${GREEN}✅ Application is healthy${NC}"
        log_with_timestamp "Health check PASSED - HTTP $response"
        return 0
    else
        echo -e "${RED}❌ Application health check failed - HTTP $response${NC}"
        log_with_timestamp "Health check FAILED - HTTP $response"
        return 1
    fi
}

# Function to check service status
check_service_status() {
    local service_status=$(systemctl is-active docuspa 2>/dev/null || echo "inactive")
    
    if [ "$service_status" = "active" ]; then
        echo -e "${GREEN}✅ DocuSpa service is running${NC}"
        log_with_timestamp "Service check PASSED - $service_status"
        return 0
    else
        echo -e "${RED}❌ DocuSpa service is not running - $service_status${NC}"
        log_with_timestamp "Service check FAILED - $service_status"
        return 1
    fi
}

# Function to check nginx status
check_nginx_status() {
    local nginx_status=$(systemctl is-active nginx 2>/dev/null || echo "inactive")
    
    if [ "$nginx_status" = "active" ]; then
        echo -e "${GREEN}✅ Nginx is running${NC}"
        log_with_timestamp "Nginx check PASSED - $nginx_status"
        return 0
    else
        echo -e "${RED}❌ Nginx is not running - $nginx_status${NC}"
        log_with_timestamp "Nginx check FAILED - $nginx_status"
        return 1
    fi
}

# Function to check database connectivity
check_database() {
    local db_check=$(python3 -c "
import os, sys
sys.path.append('/opt/docuspa')
try:
    from app.database import SessionLocal
    db = SessionLocal()
    db.execute('SELECT 1')
    db.close()
    print('connected')
except Exception as e:
    print(f'error: {e}')
" 2>/dev/null)
    
    if [[ $db_check == "connected" ]]; then
        echo -e "${GREEN}✅ Database connection is working${NC}"
        log_with_timestamp "Database check PASSED"
        return 0
    else
        echo -e "${RED}❌ Database connection failed - $db_check${NC}"
        log_with_timestamp "Database check FAILED - $db_check"
        return 1
    fi
}

# Function to check disk space
check_disk_space() {
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$disk_usage" -lt 85 ]; then
        echo -e "${GREEN}✅ Disk space is OK (${disk_usage}% used)${NC}"
        log_with_timestamp "Disk space check PASSED - ${disk_usage}% used"
        return 0
    elif [ "$disk_usage" -lt 95 ]; then
        echo -e "${YELLOW}⚠️ Disk space is getting low (${disk_usage}% used)${NC}"
        log_with_timestamp "Disk space check WARNING - ${disk_usage}% used"
        return 1
    else
        echo -e "${RED}❌ Disk space is critically low (${disk_usage}% used)${NC}"
        log_with_timestamp "Disk space check CRITICAL - ${disk_usage}% used"
        return 2
    fi
}

# Function to check memory usage
check_memory() {
    local mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2 }')
    
    if [ "$mem_usage" -lt 80 ]; then
        echo -e "${GREEN}✅ Memory usage is OK (${mem_usage}% used)${NC}"
        log_with_timestamp "Memory check PASSED - ${mem_usage}% used"
        return 0
    elif [ "$mem_usage" -lt 90 ]; then
        echo -e "${YELLOW}⚠️ Memory usage is high (${mem_usage}% used)${NC}"
        log_with_timestamp "Memory check WARNING - ${mem_usage}% used"
        return 1
    else
        echo -e "${RED}❌ Memory usage is critically high (${mem_usage}% used)${NC}"
        log_with_timestamp "Memory check CRITICAL - ${mem_usage}% used"
        return 2
    fi
}

# Function to attempt service restart
restart_services() {
    echo -e "${YELLOW}🔄 Attempting to restart services...${NC}"
    log_with_timestamp "Attempting service restart"
    
    # Restart DocuSpa service
    if systemctl restart docuspa; then
        echo -e "${GREEN}✅ DocuSpa service restarted successfully${NC}"
        log_with_timestamp "DocuSpa service restart SUCCESSFUL"
        sleep 10  # Give it time to start
        return 0
    else
        echo -e "${RED}❌ Failed to restart DocuSpa service${NC}"
        log_with_timestamp "DocuSpa service restart FAILED"
        return 1
    fi
}

# Main health check function
main() {
    echo "🏥 DocuSpa Health Check - $(date)"
    echo "========================================"
    
    # Rotate logs if needed
    rotate_logs
    
    local overall_health=0
    
    # Check service status
    if ! check_service_status; then
        overall_health=1
    fi
    
    # Check nginx status
    if ! check_nginx_status; then
        overall_health=1
    fi
    
    # Check application health (only if service is running)
    if systemctl is-active docuspa >/dev/null 2>&1; then
        if ! check_app_health; then
            overall_health=1
        fi
    fi
    
    # Check database connectivity
    if ! check_database; then
        overall_health=1
    fi
    
    # Check system resources
    check_disk_space
    local disk_status=$?
    if [ $disk_status -gt 0 ]; then
        overall_health=$disk_status
    fi
    
    check_memory
    local mem_status=$?
    if [ $mem_status -gt 0 ] && [ $mem_status -gt $overall_health ]; then
        overall_health=$mem_status
    fi
    
    echo "========================================"
    
    # Overall status
    if [ $overall_health -eq 0 ]; then
        echo -e "${GREEN}🎉 Overall Status: HEALTHY${NC}"
        log_with_timestamp "Overall health check PASSED"
    elif [ $overall_health -eq 1 ]; then
        echo -e "${YELLOW}⚠️ Overall Status: WARNING${NC}"
        log_with_timestamp "Overall health check WARNING"
        
        # Auto-restart if service is down
        if ! systemctl is-active docuspa >/dev/null 2>&1; then
            restart_services
        fi
    else
        echo -e "${RED}🚨 Overall Status: CRITICAL${NC}"
        log_with_timestamp "Overall health check CRITICAL"
    fi
    
    return $overall_health
}

# Run main function
main "$@"