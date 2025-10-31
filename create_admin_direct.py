#!/usr/bin/env python3
"""
Direct registration test - bypasses FastAPI and goes straight to the database
"""

import os
from dotenv import load_dotenv
from app.database import SessionLocal
from app.models.user import User, UserRole
from app.services.auth import get_password_hash

# Load environment variables
load_dotenv()

def create_admin_directly():
    """Create admin user directly in database"""
    db = SessionLocal()
    
    try:
        email = "wilpike@gmail.com"
        password = "admin123!"  # Shorter password for bcrypt compatibility
        
        # Check if user already exists
        existing_user = db.query(User).filter(User.email == email).first()
        if existing_user:
            print(f"❌ User {email} already exists")
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
        
        print(f"✅ Admin user created successfully!")
        print(f"   Email: {new_user.email}")
        print(f"   ID: {new_user.id}")
        print(f"   Role: {new_user.role.value}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error creating admin user: {e}")
        db.rollback()
        return False
    finally:
        db.close()

if __name__ == "__main__":
    print("🔧 Creating admin user directly...")
    create_admin_directly()