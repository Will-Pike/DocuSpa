#!/bin/bash

# DocuSpa Quick Fix for Import Issues and User Creation
# Fixes the model imports and creates users correctly

set -e

echo "🔧 DocuSpa Quick Fix Script"
echo "==========================="
echo "$(date): Fixing import issues and user creation..."

print_status() {
    echo ""
    echo "📋 $1"
    echo "----------------------------------------"
}

print_status "Stopping DocuSpa Service"
sudo systemctl stop docuspa || echo "Service not running"

print_status "Fixing User Database and Authentication"
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa
source venv/bin/activate

echo "🔑 Creating/updating users with correct imports..."

python3 << 'PYEOF'
import sys
sys.path.append('/opt/docuspa')

try:
    from app.database import SessionLocal, engine, Base  # Import Base from database
    from app.models.user import User  # Correct import path
    from app.services.auth import get_password_hash, verify_password
    from sqlalchemy import text
    
    print("✅ All imports successful")
    
    # Create tables if they don't exist
    Base.metadata.create_all(bind=engine)
    
    # Create database session
    db = SessionLocal()
    
    print("🔍 Checking and creating users...")
    
    # Check for admin user
    admin_user = db.query(User).filter(User.email == 'admin@docuspa.com').first()
    if admin_user:
        print("✅ Admin user exists")
        # Update password to ensure it's correct
        admin_user.hashed_password = get_password_hash('admin123')
        db.commit()
        print("✅ Admin password updated")
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
    
    # Test admin password
    admin_result = verify_password('admin123', admin_user.hashed_password)
    print(f"Admin password test: {'✅ PASS' if admin_result else '❌ FAIL'}")
    
    # Test will password
    will_result = verify_password('admin123!', will_user.hashed_password)
    print(f"Will Pike password test: {'✅ PASS' if will_result else '❌ FAIL'}")
    
    db.close()
    print("✅ User database operations completed successfully")
    
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
    exit(1)
PYEOF

echo "✅ User fix completed"
EOF

print_status "Creating ShareFile Database Tables"
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa
source venv/bin/activate

echo "🗄️ Setting up ShareFile credentials table..."

python3 << 'PYEOF'
import sys
sys.path.append('/opt/docuspa')

try:
    from app.database import SessionLocal, engine, Base  # Import Base from database
    from app.models.sharefile import ShareFileCredentials  # Correct import
    from sqlalchemy import text
    
    print("✅ ShareFile imports successful")
    
    # Create all tables
    Base.metadata.create_all(bind=engine)
    
    db = SessionLocal()
    
    # Test ShareFile credentials table
    try:
        result = db.execute(text("SELECT COUNT(*) FROM sharefile_credentials")).scalar()
        print(f"✅ ShareFile credentials table exists with {result} entries")
    except Exception as e:
        print(f"⚠️ ShareFile credentials table issue: {e}")
        # Try to create the table explicitly
        ShareFileCredentials.__table__.create(engine, checkfirst=True)
        print("✅ ShareFile credentials table created")
    
    db.close()
    print("✅ ShareFile database setup completed")
    
except Exception as e:
    print(f"❌ ShareFile database setup error: {e}")
    import traceback
    traceback.print_exc()
PYEOF
EOF

print_status "Testing Application Components"
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa
source venv/bin/activate

echo "🧪 Testing all critical imports..."
python3 -c "
import sys
sys.path.append('/opt/docuspa')
try:
    from app.services.auth import verify_password, get_password_hash
    from app.database import SessionLocal
    from app.models.user import User
    from app.models.sharefile import ShareFileCredentials
    print('✅ All imports successful')
except Exception as e:
    print(f'❌ Import error: {e}')
    exit(1)
"

echo "✅ All application components working"
EOF

print_status "Starting DocuSpa Service"
sudo systemctl start docuspa

sleep 5

print_status "Final Status Check"
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

if curl -f -s http://localhost:8000/ > /dev/null 2>&1; then
    echo "✅ Main application responding"
else
    echo "⚠️ Main application not responding"
fi

PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "Unknown")

print_status "Quick Fix Summary"
echo "🎉 DocuSpa quick fix completed!"
echo ""
echo "🔐 User Credentials (both should now work):"
echo "   • Admin: admin@docuspa.com / admin123"
echo "   • Will Pike: wilpike@gmail.com / admin123!"
echo ""
echo "🌐 Your Application:"
echo "   • URL: http://$PUBLIC_IP"
echo "   • Login: http://$PUBLIC_IP/login"
echo ""
echo "🔍 ShareFile Setup:"
echo "   • Go to ShareFile section after logging in"
echo "   • Complete OAuth setup with redirect URI: http://$PUBLIC_IP/admin/sharefile/oauth/callback"
echo ""

if sudo systemctl is-active --quiet docuspa; then
    echo "✅ Service is running! Try logging in now."
    echo "   Both user accounts should work."
    echo "   ShareFile OAuth should redirect properly."
else
    echo "⚠️ Service may have issues. Check logs:"
    echo "   sudo journalctl -u docuspa -n 20"
fi

echo ""
echo "$(date): Quick fix completed"
echo "==========================="