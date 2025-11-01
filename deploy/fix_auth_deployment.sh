#!/bin/bash

# DocuSpa Authentication Fix Script
# This script fixes the auth import issues on the deployed EC2 instance

set -e  # Exit on any error

echo "🔧 Starting DocuSpa authentication fix..."

# Stop the service first
echo "⏹️ Stopping DocuSpa service..."
sudo systemctl stop docuspa

# Switch to docuspa user and fix the installation
echo "🐍 Fixing Python dependencies as docuspa user..."
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa

# Activate virtual environment
source venv/bin/activate

# Reinstall critical dependencies
echo "📦 Reinstalling critical dependencies..."
pip install --force-reinstall passlib[bcrypt]==1.7.4
pip install --force-reinstall python-jose[cryptography]==3.3.0
pip install --force-reinstall bcrypt

# Test imports
echo "🧪 Testing auth imports..."
python3 -c "
import sys
sys.path.append('/opt/docuspa')
try:
    from app.services.auth import verify_password, create_access_token, verify_token, get_password_hash
    print('✅ All auth functions imported successfully')
except ImportError as e:
    print(f'❌ Import error: {e}')
    exit(1)
"

# Test bcrypt specifically
python3 -c "
try:
    from passlib.context import CryptContext
    pwd_context = CryptContext(schemes=['bcrypt'], deprecated='auto')
    test_hash = pwd_context.hash('test123')
    result = pwd_context.verify('test123', test_hash)
    print(f'✅ Bcrypt test successful: {result}')
except Exception as e:
    print(f'❌ Bcrypt test failed: {e}')
    exit(1)
"
EOF

# Pull latest code to ensure we have the correct auth.py
echo "📥 Pulling latest code..."
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa
git pull origin main
EOF

# Restart the service
echo "🚀 Starting DocuSpa service..."
sudo systemctl start docuspa

# Wait a moment for service to start
sleep 5

# Check service status
echo "📊 Checking service status..."
sudo systemctl status docuspa --no-pager -l

# Test if the API is responding
echo "🧪 Testing API response..."
sleep 2
curl -X GET http://localhost:8000/auth/test 2>/dev/null && echo "✅ API responding" || echo "❌ API not responding"

echo ""
echo "🎉 Authentication fix completed!"
echo ""
echo "📋 Service Status:"
echo "   • DocuSpa: $(sudo systemctl is-active docuspa)"
echo ""
echo "🔧 To check logs:"
echo "   sudo journalctl -u docuspa -f"
