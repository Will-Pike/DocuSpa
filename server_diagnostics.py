#!/usr/bin/env python3
"""
DocuSpa Server Diagnostics - Run this on your EC2 instance
"""

import os
import sys
import json
from pathlib import Path

# Add the project root to Python path
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

try:
    from dotenv import load_dotenv
    load_dotenv()
    
    from app.database import SessionLocal
    from app.models.user import User, UserRole
    from app.services.auth import verify_password, get_password_hash
    
    def check_database_connection():
        """Test database connectivity"""
        try:
            db = SessionLocal()
            result = db.execute("SELECT 1").fetchone()
            db.close()
            return True, "Database connection successful"
        except Exception as e:
            return False, f"Database connection failed: {e}"
    
    def check_admin_users():
        """Check admin users in database"""
        try:
            db = SessionLocal()
            admins = db.query(User).filter(User.role == UserRole.admin).all()
            db.close()
            
            admin_info = []
            for admin in admins:
                admin_info.append({
                    "id": admin.id,
                    "email": admin.email,
                    "role": admin.role.value,
                    "created_at": str(admin.created_at)
                })
            
            return True, admin_info
        except Exception as e:
            return False, f"Failed to query admin users: {e}"
    
    def test_password_verification():
        """Test password verification for known admin"""
        try:
            db = SessionLocal()
            admin = db.query(User).filter(User.email == "wilpike@gmail.com").first()
            
            if not admin:
                return False, "wilpike@gmail.com admin not found"
            
            # Test with the expected password
            test_passwords = ["admin123!", "admin2025!@", "AdminPass123!"]
            results = {}
            
            for pwd in test_passwords:
                is_valid = verify_password(pwd, admin.password_hash)
                results[pwd] = is_valid
            
            db.close()
            return True, results
        except Exception as e:
            return False, f"Password verification test failed: {e}"
    
    def check_environment():
        """Check environment configuration"""
        env_vars = {
            "SECRET_KEY": os.getenv("SECRET_KEY", "NOT SET"),
            "DATABASE_URL": os.getenv("DATABASE_URL", "NOT SET"),
            "ALGORITHM": os.getenv("ALGORITHM", "NOT SET"),
            "ENVIRONMENT": os.getenv("ENVIRONMENT", "NOT SET")
        }
        
        # Mask sensitive data
        if env_vars["SECRET_KEY"] != "NOT SET":
            env_vars["SECRET_KEY"] = env_vars["SECRET_KEY"][:10] + "..." if len(env_vars["SECRET_KEY"]) > 10 else "SET"
        
        if env_vars["DATABASE_URL"] != "NOT SET":
            env_vars["DATABASE_URL"] = "SET (database URL configured)"
        
        return env_vars
    
    def run_diagnostics():
        """Run all diagnostic checks"""
        print("🏥 DocuSpa Server Diagnostics")
        print("=" * 50)
        
        # Check environment
        print("\n📋 Environment Configuration:")
        env_config = check_environment()
        for key, value in env_config.items():
            print(f"   {key}: {value}")
        
        # Check database
        print("\n🗄️  Database Connection:")
        db_success, db_msg = check_database_connection()
        print(f"   Status: {'✅ PASS' if db_success else '❌ FAIL'}")
        print(f"   Message: {db_msg}")
        
        if db_success:
            # Check admin users
            print("\n👥 Admin Users:")
            admin_success, admin_data = check_admin_users()
            if admin_success:
                print(f"   Found {len(admin_data)} admin user(s):")
                for admin in admin_data:
                    print(f"     • {admin['email']} (ID: {admin['id']})")
            else:
                print(f"   ❌ FAIL: {admin_data}")
            
            # Test password verification
            print("\n🔐 Password Verification Test:")
            pwd_success, pwd_results = test_password_verification()
            if pwd_success:
                if isinstance(pwd_results, dict):
                    for pwd, is_valid in pwd_results.items():
                        status = "✅ VALID" if is_valid else "❌ INVALID"
                        print(f"   Password '{pwd}': {status}")
                else:
                    print(f"   ❌ {pwd_results}")
            else:
                print(f"   ❌ FAIL: {pwd_results}")
        
        # Check if server is running
        print("\n🚀 Server Status:")
        try:
            import requests
            response = requests.get("http://localhost:8000/health", timeout=5)
            print(f"   Health endpoint: ✅ HTTP {response.status_code}")
        except Exception as e:
            print(f"   Health endpoint: ❌ {e}")
        
        # Check auth endpoint
        try:
            import requests
            response = requests.get("http://localhost:8000/auth/test", timeout=5)
            print(f"   Auth test endpoint: ✅ HTTP {response.status_code}")
            if response.status_code == 200:
                print(f"   Auth service: ✅ {response.json().get('message', 'OK')}")
        except Exception as e:
            print(f"   Auth test endpoint: ❌ {e}")
        
        print("\n" + "=" * 50)
        print("🔧 Troubleshooting Tips:")
        print("   1. Ensure DocuSpa service is running: sudo systemctl status docuspa")
        print("   2. Check application logs: sudo journalctl -u docuspa -f")
        print("   3. Verify nginx is running: sudo systemctl status nginx")
        print("   4. Check nginx logs: sudo tail -f /var/log/nginx/error.log")
        print("   5. Test direct access: curl http://localhost:8000/health")

except ImportError as e:
    print(f"❌ Import error: {e}")
    print("Make sure you're running this from the DocuSpa directory with:")
    print("   cd /opt/docuspa && python3 server_diagnostics.py")
    sys.exit(1)

if __name__ == "__main__":
    run_diagnostics()