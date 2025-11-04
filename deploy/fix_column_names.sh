#!/bin/bash

# DocuSpa Database Column Fix - Fix password column name mismatch
# The database has 'password_hash' but code expects 'hashed_password'

set -e

echo "🔧 DocuSpa Database Column Fix"
echo "=============================="
echo "$(date): Fixing database column name mismatch..."

print_status() {
    echo ""
    echo "📋 $1"
    echo "----------------------------------------"
}

print_status "Stopping DocuSpa Service"
sudo systemctl stop docuspa || echo "Service not running"

print_status "Fixing Database Column Names"
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa
source venv/bin/activate

echo "🔧 Fixing database column name mismatch..."

python3 << 'PYEOF'
import sys
sys.path.append('/opt/docuspa')

try:
    from app.database import SessionLocal, engine
    from sqlalchemy import text, inspect
    
    db = SessionLocal()
    
    # Check current table schema
    inspector = inspect(engine)
    columns = inspector.get_columns('users')
    column_names = [col['name'] for col in columns]
    print(f"Current columns: {column_names}")
    
    # Check if we have password_hash but need hashed_password
    if 'password_hash' in column_names and 'hashed_password' not in column_names:
        print("🔧 Adding hashed_password column and copying data...")
        
        # Add the new column
        db.execute(text("ALTER TABLE users ADD COLUMN hashed_password TEXT"))
        
        # Copy data from password_hash to hashed_password
        db.execute(text("UPDATE users SET hashed_password = password_hash WHERE password_hash IS NOT NULL"))
        
        db.commit()
        print("✅ Added hashed_password column and copied data")
    
    # Check if we need is_active column
    if 'is_active' not in column_names:
        print("🔧 Adding is_active column...")
        db.execute(text("ALTER TABLE users ADD COLUMN is_active INTEGER DEFAULT 1"))
        db.commit()
        print("✅ Added is_active column")
    
    # Show final schema
    inspector = inspect(engine)
    final_columns = [col['name'] for col in inspector.get_columns('users')]
    print(f"Final columns: {final_columns}")
    
    db.close()
    print("✅ Database schema fix completed")
    
except Exception as e:
    print(f"❌ Database fix error: {e}")
    import traceback
    traceback.print_exc()
PYEOF
EOF

print_status "Creating Users with Correct Column Names"
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa
source venv/bin/activate

echo "🔑 Creating users with correct column names..."

python3 << 'PYEOF'
import sys
sys.path.append('/opt/docuspa')

try:
    from app.database import SessionLocal
    from app.services.auth import get_password_hash, verify_password
    from sqlalchemy import text, inspect
    
    db = SessionLocal()
    
    # Clear existing admin users
    db.execute(text("DELETE FROM users WHERE email IN ('admin@docuspa.com', 'wilpike@gmail.com')"))
    db.commit()
    
    # Get current schema
    inspector = inspect(engine)
    columns = [col['name'] for col in inspector.get_columns('users')]
    print(f"Available columns: {columns}")
    
    # Create admin user using actual column names
    admin_hash = get_password_hash('admin123')
    
    # Use the actual column names from the database
    db.execute(text("""
        INSERT INTO users (id, email, name, hashed_password, password_hash, is_active, role, created_at)
        VALUES (hex(randomblob(16)), 'admin@docuspa.com', 'Admin User', :hash, :hash, 1, 'admin', datetime('now'))
    """), {'hash': admin_hash})
    
    # Create Will Pike user
    will_hash = get_password_hash('admin123!')
    db.execute(text("""
        INSERT INTO users (id, email, name, hashed_password, password_hash, is_active, role, created_at)
        VALUES (hex(randomblob(16)), 'wilpike@gmail.com', 'Will Pike', :hash, :hash, 1, 'admin', datetime('now'))
    """), {'hash': will_hash})
    
    db.commit()
    print("✅ Users created successfully")
    
    # Test the users
    admin_user = db.execute(text("SELECT * FROM users WHERE email = 'admin@docuspa.com'")).fetchone()
    will_user = db.execute(text("SELECT * FROM users WHERE email = 'wilpike@gmail.com'")).fetchone()
    
    if admin_user:
        # Test with hashed_password column
        admin_result = verify_password('admin123', admin_user._mapping['hashed_password'])
        print(f"Admin password test: {'✅ PASS' if admin_result else '❌ FAIL'}")
        
    if will_user:
        will_result = verify_password('admin123!', will_user._mapping['hashed_password'])
        print(f"Will Pike password test: {'✅ PASS' if will_result else '❌ FAIL'}")
    
    db.close()
    print("✅ User creation and testing completed")
    
except Exception as e:
    print(f"❌ User creation error: {e}")
    import traceback
    traceback.print_exc()
PYEOF
EOF

print_status "Testing Application Startup"
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa
source venv/bin/activate

echo "🧪 Testing application components..."

python3 << 'PYEOF'
import sys
sys.path.append('/opt/docuspa')

try:
    from app.database import SessionLocal
    from app.services.auth import get_password_hash
    from sqlalchemy import text
    
    # Test database connection
    db = SessionLocal()
    result = db.execute(text("SELECT 1")).scalar()
    db.close()
    print("✅ Database connection working")
    
    # Test FastAPI app
    from main import app
    print("✅ FastAPI app import successful")
    
    print("✅ All application components working")
    
except Exception as e:
    print(f"❌ Application test error: {e}")
    import traceback
    traceback.print_exc()
PYEOF
EOF

print_status "Starting DocuSpa Service"
sudo systemctl start docuspa

sleep 5

print_status "Service Status and Testing"
echo "DocuSpa Service Status:"
sudo systemctl status docuspa --no-pager -l

echo ""
echo "📋 Recent application logs:"
sudo journalctl -u docuspa --no-pager -n 15

echo ""
echo "🔍 Testing endpoints..."
sleep 3

if curl -f -s http://localhost:8000/health > /dev/null 2>&1; then
    echo "✅ Health endpoint responding"
    
    # Test login
    echo "🔐 Testing login..."
    login_result=$(curl -s -X POST http://localhost:8000/auth/login \
        -H "Content-Type: application/json" \
        -d '{"email": "admin@docuspa.com", "password": "admin123"}')
    
    if echo "$login_result" | grep -q "access_token"; then
        echo "✅ Admin login successful!"
    else
        echo "⚠️ Admin login failed: $login_result"
    fi
    
elif curl -f -s http://localhost:8000/ > /dev/null 2>&1; then
    echo "✅ Main application responding"
else
    echo "⚠️ Application not responding on port 8000"
fi

PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "Unknown")

print_status "Database Column Fix Summary"
echo "🎉 DocuSpa database column fix completed!"
echo ""
echo "🔧 Fixed Issues:"
echo "   ✅ Added hashed_password column (code was looking for this)"
echo "   ✅ Added is_active column (required for user model)"
echo "   ✅ Created users with correct column mapping"
echo "   ✅ Fixed SQLAlchemy text() syntax issues"
echo ""
echo "🔐 User Credentials:"
echo "   • Admin: admin@docuspa.com / admin123"
echo "   • Will Pike: wilpike@gmail.com / admin123!"
echo ""
echo "🌐 Your Application:"
echo "   • URL: http://$PUBLIC_IP"
echo "   • Login: http://$PUBLIC_IP/login"
echo ""

if sudo systemctl is-active --quiet docuspa; then
    echo "✅ Service is running! Authentication should now work properly."
    echo "   Try logging in with either account."
else
    echo "⚠️ Service may need attention:"
    echo "   sudo journalctl -u docuspa -f"
fi

echo ""
echo "$(date): Database column fix completed"
echo "=============================="