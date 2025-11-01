# DocuSpa Deployment Fix using AWS Systems Manager
# This script uses AWS Systems Manager Session Manager to connect without SSH keys

param(
    [Parameter(Mandatory=$true)]
    [string]$InstanceId,
    
    [string]$Region = "us-east-1"
)

Write-Host "DocuSpa Authentication Fix via AWS Systems Manager" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green

# Check if AWS CLI is installed
try {
    aws --version | Out-Null
} catch {
    Write-Host "AWS CLI not found. Please install AWS CLI first:" -ForegroundColor Red
    Write-Host "https://aws.amazon.com/cli/" -ForegroundColor Yellow
    exit 1
}

# Check if Session Manager plugin is installed
try {
    aws ssm start-session --help | Out-Null
} catch {
    Write-Host "Session Manager plugin not found. Please install it:" -ForegroundColor Red
    Write-Host "https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html" -ForegroundColor Yellow
    exit 1
}

Write-Host "Instance ID: $InstanceId" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow

try {
    # Create a temporary script that combines all our fixes
    $TempScript = @"
#!/bin/bash
set -e

echo "Starting DocuSpa authentication fix..."

# Stop the service first
echo "Stopping DocuSpa service..."
sudo systemctl stop docuspa

# Switch to docuspa user and fix the installation
echo "Fixing Python dependencies as docuspa user..."
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa

# Activate virtual environment
source venv/bin/activate

# Reinstall critical dependencies
echo "Reinstalling critical dependencies..."
pip install --force-reinstall passlib[bcrypt]==1.7.4
pip install --force-reinstall python-jose[cryptography]==3.3.0
pip install --force-reinstall bcrypt

# Test imports
echo "Testing auth imports..."
python3 -c "
import sys
sys.path.append('/opt/docuspa')
try:
    from app.services.auth import verify_password, create_access_token, verify_token, get_password_hash
    print('All auth functions imported successfully')
except ImportError as e:
    print(f'Import error: {e}')
    exit(1)
"

# Test bcrypt specifically
python3 -c "
try:
    from passlib.context import CryptContext
    pwd_context = CryptContext(schemes=['bcrypt'], deprecated='auto')
    test_hash = pwd_context.hash('test123')
    result = pwd_context.verify('test123', test_hash)
    print(f'Bcrypt test successful: {result}')
except Exception as e:
    print(f'Bcrypt test failed: {e}')
    exit(1)
"
EOF

# Pull latest code to ensure we have the correct auth.py
echo "Pulling latest code..."
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa
git pull origin main
EOF

# Restart the service
echo "Starting DocuSpa service..."
sudo systemctl start docuspa

# Wait a moment for service to start
sleep 5

# Check service status
echo "Checking service status..."
sudo systemctl status docuspa --no-pager -l

# Test if the API is responding
echo "Testing API response..."
sleep 2
curl -X GET http://localhost:8000/auth/test 2>/dev/null || echo "API test endpoint not responding"

echo ""
echo "Authentication fix completed!"
"@

    # Save the script to a temporary file
    $TempScriptPath = "$env:TEMP\fix_docuspa.sh"
    $TempScript | Out-File -FilePath $TempScriptPath -Encoding UTF8

    Write-Host "`nConnecting to instance via Session Manager..." -ForegroundColor Cyan
    Write-Host "This will open an interactive session. You'll need to:" -ForegroundColor Yellow
    Write-Host "1. Copy and paste the fix commands" -ForegroundColor White
    Write-Host "2. Or manually type the commands" -ForegroundColor White
    Write-Host "`nPress Enter to continue..." -ForegroundColor Yellow
    Read-Host

    # Start Session Manager session
    aws ssm start-session --target $InstanceId --region $Region

} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Ensure your AWS credentials are configured: aws configure" -ForegroundColor White
    Write-Host "2. Ensure the EC2 instance has SSM permissions" -ForegroundColor White
    Write-Host "3. Ensure Session Manager plugin is installed" -ForegroundColor White
    exit 1
}

Write-Host "`nAfter connecting, run these commands in the session:" -ForegroundColor Green
Write-Host $TempScript -ForegroundColor Cyan
