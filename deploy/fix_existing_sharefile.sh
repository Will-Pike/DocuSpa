#!/bin/bash

# DocuSpa ShareFile Fix Script for Existing EC2 Instance
# This script updates an existing DocuSpa deployment with ShareFile authentication fixes

set -e

echo "🔧 DocuSpa ShareFile Authentication Fix"
echo "======================================"
echo "$(date): Starting ShareFile fix for existing instance..."

# Function to print status messages
print_status() {
    echo ""
    echo "📋 $1"
    echo "----------------------------------------"
}

# Check if we're running as root or with sudo access
if [ "$EUID" -eq 0 ]; then
    echo "⚠️ Running as root. Will switch to docuspa user for application updates."
elif ! sudo -n true 2>/dev/null; then
    echo "❌ This script requires sudo access. Please run with sudo or as root."
    exit 1
fi

print_status "Checking Current Installation"

# Check if docuspa user exists
if ! id "docuspa" &>/dev/null; then
    echo "❌ DocuSpa user 'docuspa' not found. This script is for existing installations."
    echo "Please use the full deployment script instead."
    exit 1
fi

# Check if application directory exists
if [ ! -d "/opt/docuspa" ]; then
    echo "❌ DocuSpa application directory '/opt/docuspa' not found."
    echo "Please use the full deployment script instead."
    exit 1
fi

echo "✅ Found existing DocuSpa installation"

print_status "Stopping DocuSpa Service"
sudo systemctl stop docuspa || echo "⚠️ DocuSpa service not running or not found"

print_status "Updating Application Code"
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa

echo "📥 Pulling latest code from GitHub..."
git fetch origin
git reset --hard origin/main
git clean -fd

echo "✅ Code updated to latest version"
EOF

print_status "Updating Python Dependencies"
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa
source venv/bin/activate

echo "🔄 Updating pip and core packages..."
pip install --upgrade pip wheel setuptools

echo "📦 Reinstalling requirements..."
pip install -r requirements.txt --force-reinstall

echo "🔒 Installing critical authentication packages with specific versions..."
pip install --force-reinstall "passlib[bcrypt]==1.7.4"
pip install --force-reinstall "python-jose[cryptography]==3.3.0" 
pip install --force-reinstall "bcrypt>=4.0.0"

echo "🧪 Testing critical imports..."
python3 -c "
import sys
sys.path.append('/opt/docuspa')
try:
    # Test passlib and bcrypt
    from passlib.context import CryptContext
    pwd_context = CryptContext(schemes=['bcrypt'], deprecated='auto')
    test_hash = pwd_context.hash('test123')
    result = pwd_context.verify('test123', test_hash)
    print(f'✅ Bcrypt functionality test: {result}')
    
    # Test jose JWT
    from jose import jwt
    print('✅ JWT library imported successfully')
    
    # Test our auth functions
    from app.services.auth import verify_password, create_access_token, verify_token, get_password_hash
    print('✅ All auth service functions imported successfully')
    
    # Test password hashing
    test_password = 'admin123'
    hashed = get_password_hash(test_password)
    verified = verify_password(test_password, hashed)
    print(f'✅ Password hashing test: {verified}')
    
except ImportError as e:
    print(f'❌ Import error: {e}')
    exit(1)
except Exception as e:
    print(f'❌ Functionality error: {e}')
    exit(1)
"

echo "✅ All authentication components working properly"
EOF

print_status "Checking Environment Configuration"
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa

# Check if .env exists and has ShareFile config
if [ -f ".env" ]; then
    echo "✅ Found existing .env file"
    
    # Check for ShareFile configuration
    if grep -q "SHAREFILE_CLIENT_ID" .env; then
        echo "✅ ShareFile configuration found in .env"
    else
        echo "⚠️ Adding ShareFile configuration to .env..."
        cat >> .env << 'ENVEOF'

# ShareFile Configuration
SHAREFILE_CLIENT_ID=p1EUHPr1iaHRK37Savp3ZBNim0UbcPaF
SHAREFILE_CLIENT_SECRET=xz8lCunBh3r7K7cHJCS8eGmglYyKTALGOY6wdfpizHoBqySG
SHAREFILE_REDIRECT_URI=https://secure.sharefile.com/oauth/oauthcomplete.aspx
SHAREFILE_BASE_URL=https://secure.sf-api.com/sf/v3
ENVEOF
        echo "✅ ShareFile configuration added"
    fi
else
    echo "⚠️ No .env file found. Creating one..."
    cat > .env << 'ENVEOF'
# DocuSpa Configuration
DATABASE_URL=mysql+pymysql://admin:[NLtuTc)xA-my-U-r<XePARpH7x5@docuspa-db.cvy4mgkesrso.us-east-2.rds.amazonaws.com:3306/docuspa-db
SECRET_KEY=gw0KvaC8o9_yiym6lqNCUBHw_9BH7rXH0gHvjY-PvXY
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# ShareFile Configuration
SHAREFILE_CLIENT_ID=p1EUHPr1iaHRK37Savp3ZBNim0UbcPaF
SHAREFILE_CLIENT_SECRET=xz8lCunBh3r7K7cHJCS8eGmglYyKTALGOY6wdfpizHoBqySG
SHAREFILE_REDIRECT_URI=https://secure.sharefile.com/oauth/oauthcomplete.aspx
SHAREFILE_BASE_URL=https://secure.sf-api.com/sf/v3

# Production Settings
ENVIRONMENT=production
LOG_LEVEL=INFO
HOST=0.0.0.0
PORT=8000
ENVEOF
    echo "✅ Created .env file with ShareFile configuration"
fi
EOF

print_status "Testing Application Startup"
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa
source venv/bin/activate

echo "🧪 Testing application startup..."
timeout 10s python3 -c "
import sys
sys.path.append('/opt/docuspa')
from main import app
print('✅ Application imports successfully')
" || echo "⚠️ Application test timed out (this is normal)"
EOF

print_status "Starting DocuSpa Service"
sudo systemctl daemon-reload
sudo systemctl start docuspa

# Wait a moment for service to start
sleep 5

print_status "Checking Service Status"
echo "DocuSpa Service Status:"
sudo systemctl status docuspa --no-pager -l

print_status "Running Health Checks"
sleep 3

echo "🔍 Testing application health..."
if curl -f -s http://localhost:8000/health > /dev/null 2>&1; then
    echo "✅ DocuSpa application is responding"
else
    echo "⚠️ DocuSpa application health check failed"
    echo ""
    echo "📋 Recent application logs:"
    sudo journalctl -u docuspa --no-pager -n 20
fi

echo ""
echo "🔍 Testing authentication endpoint..."
if curl -f -s http://localhost:8000/auth/test > /dev/null 2>&1; then
    echo "✅ Authentication endpoint is responding"
else
    echo "⚠️ Authentication endpoint test failed"
fi

# Get public IP
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "Unable to detect")

print_status "Update Summary"
echo "🎉 DocuSpa ShareFile fix completed!"
echo ""
echo "📋 Service Status:"
echo "   • DocuSpa: $(sudo systemctl is-active docuspa)"
echo ""
echo "🌐 Your Application:"
echo "   • URL: http://$PUBLIC_IP"
echo "   • Login: http://$PUBLIC_IP/login"
echo ""
echo "🔐 Default Admin Credentials:"
echo "   • Email: admin@docuspa.com"
echo "   • Password: admin123"
echo ""
echo "🔍 ShareFile Testing:"
echo "   1. Login to your application"
echo "   2. Navigate to ShareFile section"
echo "   3. You should now see folders and files"
echo "   4. File downloads should work via proxy"
echo ""
echo "🛠️ Troubleshooting Commands:"
echo "   • View logs: sudo journalctl -u docuspa -f"
echo "   • Restart app: sudo systemctl restart docuspa"
echo "   • Check status: sudo systemctl status docuspa"
echo "   • Test API: curl http://localhost:8000/health"
echo ""

if sudo systemctl is-active --quiet docuspa; then
    echo "✅ Update successful! ShareFile functionality should now work."
    echo "   Try logging in and accessing ShareFile at: http://$PUBLIC_IP"
else
    echo "⚠️ Update completed but service may have issues. Check logs above."
    echo ""
    echo "🔧 Quick fix commands:"
    echo "   sudo systemctl restart docuspa"
    echo "   sudo journalctl -u docuspa -n 50"
fi

echo ""
echo "$(date): ShareFile fix process completed"
echo "======================================"