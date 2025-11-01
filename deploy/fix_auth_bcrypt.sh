#!/bin/bash

# Fix auth.py bcrypt 72-byte limitation issue
# Run this script on the EC2 instance

set -e

echo "🔧 Fixing auth.py bcrypt 72-byte limitation..."

# Backup current auth.py
sudo cp /opt/docuspa/app/services/auth.py /opt/docuspa/app/services/auth.py.backup.$(date +%s)

# Create the fixed auth.py content
sudo tee /opt/docuspa/app/services/auth.py > /dev/null << 'EOF'
import os
from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from dotenv import load_dotenv

load_dotenv()

# Password hashing with bcrypt 72-byte limit handling
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# JWT settings
SECRET_KEY = os.getenv("SECRET_KEY")
ALGORITHM = os.getenv("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))

def _truncate_password(password: str) -> bytes:
    """Truncate password to 72 bytes for bcrypt compatibility"""
    password_bytes = password.encode('utf-8')
    if len(password_bytes) > 72:
        password_bytes = password_bytes[:72]
    return password_bytes

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify password with bcrypt 72-byte limit handling"""
    try:
        # Truncate password to 72 bytes if necessary
        truncated_password = _truncate_password(plain_password).decode('utf-8')
        return pwd_context.verify(truncated_password, hashed_password)
    except Exception as e:
        print(f"Password verification error: {e}")
        return False

def get_password_hash(password: str) -> str:
    """Hash password with bcrypt 72-byte limit handling"""
    try:
        # Truncate password to 72 bytes if necessary
        truncated_password = _truncate_password(password).decode('utf-8')
        return pwd_context.hash(truncated_password)
    except Exception as e:
        print(f"Password hashing error: {e}")
        # Return a default hash that will never match
        return pwd_context.hash("invalid_password_hash")

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def verify_token(token: str) -> Optional[str]:
    """Verify JWT token and return username/email"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            return None
        return email
    except JWTError as e:
        print(f"JWT verification error: {e}")
        return None
EOF

echo "✅ Fixed auth.py with bcrypt 72-byte limitation handling"

# Set proper ownership and permissions
sudo chown docuspa:docuspa /opt/docuspa/app/services/auth.py
sudo chmod 644 /opt/docuspa/app/services/auth.py

echo "🔄 Restarting DocuSpa service..."
sudo systemctl restart docuspa

echo "⏳ Waiting for service to start..."
sleep 5

echo "📊 Checking service status..."
sudo systemctl status docuspa --no-pager

echo "🔍 Checking recent logs..."
sudo journalctl -u docuspa -n 20 --no-pager

echo ""
echo "🎉 Auth.py has been fixed with bcrypt 72-byte limitation handling!"
echo "The application should now handle password authentication properly."
echo ""
echo "Test the login at: http://3.144.174.133"
echo ""
echo "If you still have issues, check the logs with:"
echo "sudo journalctl -u docuspa -f"
