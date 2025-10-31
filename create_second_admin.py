#!/usr/bin/env python3
"""
Create additional admin user - techrancher67@gmail.com
"""

import os
from dotenv import load_dotenv
from app.database import SessionLocal
from app.models.user import User, UserRole
from app.services.auth import get_password_hash

# Load environment variables
load_dotenv()

def create_second_admin():
    """Create second admin user directly in database"""
    db = SessionLocal()
    
    try:
        email = "techrancher67@gmail.com"
        password = "admin123!"
        
        # Check if user already exists
        existing_user = db.query(User).filter(User.email == email).first()
        if existing_user:
            print(f"❌ User {email} already exists")
            print(f"   ID: {existing_user.id}")
            print(f"   Role: {existing_user.role.value}")
            return False
        
        # Create new admin user
        hashed_password = get_password_hash(password)
        
        new_user = User(
            email=email,
            password_hash=hashed_password,
            role=UserRole.admin
        )
        
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        
        print(f"✅ Second admin user created successfully!")
        print(f"   Email: {new_user.email}")
        print(f"   ID: {new_user.id}")
        print(f"   Role: {new_user.role.value}")
        print(f"   Created: {new_user.created_at}")
        
        # List all admin users
        print(f"\n📋 All admin users:")
        all_admins = db.query(User).filter(User.role == UserRole.admin).all()
        for admin in all_admins:
            print(f"   • {admin.email} (ID: {admin.id})")
        
        return True
        
    except Exception as e:
        print(f"❌ Error creating admin user: {e}")
        db.rollback()
        return False
    finally:
        db.close()

if __name__ == "__main__":
    print("🔧 Creating second admin user: techrancher67@gmail.com")
    create_second_admin()