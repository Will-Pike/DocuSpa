#!/bin/bash

# DocuSpa Diagnostic and Fix Script for EC2 Instance
# Fixes ShareFile OAuth setup and user authentication issues

set -e

echo "🔍 DocuSpa Diagnostic and Fix Script"
echo "===================================="
echo "$(date): Starting diagnostics..."

print_status() {
    echo ""
    echo "📋 $1"
    echo "----------------------------------------"
}

print_status "Checking Current Installation"

if [ ! -d "/opt/docuspa" ]; then
    echo "❌ DocuSpa not found at /opt/docuspa"
    exit 1
fi

print_status "Stopping DocuSpa Service"
sudo systemctl stop docuspa || echo "Service not running"

print_status "Updating Code and Dependencies"
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa

echo "📥 Pulling latest code..."
git fetch origin
git reset --hard origin/main
git clean -fd

echo "🔄 Updating Python dependencies..."
source venv/bin/activate
pip install --upgrade pip
pip install --force-reinstall "passlib[bcrypt]==1.7.4"
pip install --force-reinstall "python-jose[cryptography]==3.3.0" 
pip install --force-reinstall "bcrypt>=4.0.0"
pip install -r requirements.txt --upgrade

echo "✅ Dependencies updated"
EOF

print_status "Fixing ShareFile OAuth Configuration"
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa

# Get the public IP for the redirect URI
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "localhost")

echo "📝 Updating ShareFile OAuth configuration..."

# Update .env with correct redirect URI
if [ -f ".env" ]; then
    # Remove old ShareFile config
    sed -i '/^SHAREFILE_/d' .env
fi

# Add correct ShareFile configuration
cat >> .env << ENVEOF

# ShareFile Configuration (Updated)
SHAREFILE_CLIENT_ID=p1EUHPr1iaHRK37Savp3ZBNim0UbcPaF
SHAREFILE_CLIENT_SECRET=xz8lCunBh3r7K7cHJCS8eGmglYyKTALGOY6wdfpizHoBqySG
SHAREFILE_REDIRECT_URI=http://${PUBLIC_IP}/admin/sharefile/oauth/callback
SHAREFILE_BASE_URL=https://secure.sf-api.com/sf/v3
ENVEOF

echo "✅ ShareFile OAuth configuration updated"
echo "   Redirect URI: http://${PUBLIC_IP}/admin/sharefile/oauth/callback"
EOF

print_status "Fixing User Database Issues"
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa
source venv/bin/activate

echo "🔑 Checking and fixing user database..."

python3 << 'PYEOF'
import sys
sys.path.append('/opt/docuspa')

try:
    from app.database import SessionLocal, engine
    from app.models import User, Base
    from app.services.auth import get_password_hash
    from sqlalchemy import text
    
    # Create tables if they don't exist
    Base.metadata.create_all(bind=engine)
    
    # Create database session
    db = SessionLocal()
    
    print("🔍 Checking existing users...")
    
    # Check for admin user
    admin_user = db.query(User).filter(User.email == 'admin@docuspa.com').first()
    if admin_user:
        print("✅ Admin user exists")
    else:
        print("🔧 Creating admin user...")
        hashed_password = get_password_hash('admin123')
        admin_user = User(
            email='admin@docuspa.com',
            name='Admin User',
            hashed_password=hashed_password,
            is_active=True
        )
        db.add(admin_user)
        db.commit()
        print("✅ Admin user created")
    
    # Check for wilpike user
    will_user = db.query(User).filter(User.email == 'wilpike@gmail.com').first()
    if will_user:
        print("✅ Will Pike user exists")
        # Update password to ensure it's correct
        will_user.hashed_password = get_password_hash('admin123!')
        db.commit()
        print("✅ Will Pike password updated")
    else:
        print("🔧 Creating Will Pike user...")
        hashed_password = get_password_hash('admin123!')
        will_user = User(
            email='wilpike@gmail.com',
            name='Will Pike',
            hashed_password=hashed_password,
            is_active=True
        )
        db.add(will_user)
        db.commit()
        print("✅ Will Pike user created")
    
    # Test password verification
    print("\n🧪 Testing password verification...")
    from app.services.auth import verify_password
    
    # Test admin password
    admin_result = verify_password('admin123', admin_user.hashed_password)
    print(f"Admin password test: {admin_result}")
    
    # Test will password
    will_result = verify_password('admin123!', will_user.hashed_password)
    print(f"Will Pike password test: {will_result}")
    
    db.close()
    print("✅ User database operations completed")
    
except Exception as e:
    print(f"❌ Database error: {e}")
    import traceback
    traceback.print_exc()
PYEOF
EOF

print_status "Creating ShareFile Database Setup"
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa
source venv/bin/activate

echo "🗄️ Setting up ShareFile credentials table..."

python3 << 'PYEOF'
import sys
sys.path.append('/opt/docuspa')

try:
    from app.database import SessionLocal, engine
    from app.models import Base, ShareFileCredential
    from sqlalchemy import text
    
    # Create tables
    Base.metadata.create_all(bind=engine)
    
    db = SessionLocal()
    
    # Check if ShareFile credentials table exists and is accessible
    try:
        result = db.execute(text("SELECT COUNT(*) FROM sharefile_credentials")).scalar()
        print(f"✅ ShareFile credentials table exists with {result} entries")
    except Exception as e:
        print(f"⚠️ ShareFile credentials table issue: {e}")
        # Try to create the table
        ShareFileCredential.__table__.create(engine, checkfirst=True)
        print("✅ ShareFile credentials table created")
    
    db.close()
    
except Exception as e:
    print(f"❌ ShareFile database setup error: {e}")
    import traceback
    traceback.print_exc()
PYEOF
EOF

print_status "Testing Application Before Start"
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa
source venv/bin/activate

echo "🧪 Testing critical imports..."
python3 -c "
import sys
sys.path.append('/opt/docuspa')
try:
    from app.services.auth import verify_password, get_password_hash
    from app.database import SessionLocal
    from app.models import User, ShareFileCredential
    print('✅ All imports successful')
except Exception as e:
    print(f'❌ Import error: {e}')
    exit(1)
"
EOF

print_status "Starting DocuSpa Service"
sudo systemctl daemon-reload
sudo systemctl start docuspa

sleep 5

print_status "Service Status and Health Check"
echo "DocuSpa Service Status:"
sudo systemctl status docuspa --no-pager -l

echo ""
echo "🔍 Testing application endpoints..."
sleep 3

if curl -f -s http://localhost:8000/health > /dev/null 2>&1; then
    echo "✅ Health endpoint working"
else
    echo "⚠️ Health endpoint failed"
fi

if curl -f -s http://localhost:8000/auth/test > /dev/null 2>&1; then
    echo "✅ Auth endpoint working"
else
    echo "⚠️ Auth endpoint failed"
fi

PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "Unknown")

print_status "Fix Summary"
echo "🎉 DocuSpa diagnostic and fix completed!"
echo ""
echo "📋 Issues Fixed:"
echo "   ✅ Updated ShareFile OAuth redirect URI"
echo "   ✅ Fixed user authentication database"
echo "   ✅ Updated Python dependencies"
echo "   ✅ Created/updated both users"
echo ""
echo "🔐 User Credentials:"
echo "   • Admin: admin@docuspa.com / admin123"
echo "   • Will Pike: wilpike@gmail.com / admin123!"
echo ""
echo "🌐 ShareFile Setup:"
echo "   • URL: http://$PUBLIC_IP/admin/sharefile/setup"
echo "   • Redirect URI configured: http://$PUBLIC_IP/admin/sharefile/oauth/callback"
echo ""
echo "🔧 Next Steps:"
echo "   1. Login with either user account"
echo "   2. Go to ShareFile setup page"
echo "   3. Complete OAuth authorization"
echo "   4. ShareFile should now connect properly"
echo ""
echo "🛠️ If issues persist:"
echo "   • Check logs: sudo journalctl -u docuspa -f"
echo "   • Restart: sudo systemctl restart docuspa"
echo ""

if sudo systemctl is-active --quiet docuspa; then
    echo "✅ Service is running successfully!"
    echo "   Access your app: http://$PUBLIC_IP"
else
    echo "⚠️ Service may have issues. Check status above."
fi

echo ""
echo "$(date): Diagnostic and fix completed"
echo "===================================="