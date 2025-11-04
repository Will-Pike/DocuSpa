#!/bin/bash

# DocuSpa Instance Connect Deployment Script
# This script is designed to be run via AWS Instance Connect
# It includes the latest fixes and optimizations for the authentication system

set -e  # Exit on any error

echo "🚀 DocuSpa Instance Connect Deployment Started"
echo "=============================================="
echo "$(date): Starting deployment process..."

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print status messages
print_status() {
    echo ""
    echo "📋 $1"
    echo "----------------------------------------"
}

print_status "System Information"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "OS: $NAME $VERSION_ID"
    OS_NAME="$NAME"
else
    echo "❌ Cannot detect operating system"
    exit 1
fi

# Check if we're on a supported OS
if [[ "$OS_NAME" != *"Amazon Linux"* ]] && [[ "$OS_NAME" != *"Ubuntu"* ]] && [[ "$OS_NAME" != *"Debian"* ]]; then
    echo "❌ Unsupported OS: $OS_NAME"
    echo "This script supports Amazon Linux 2023, Ubuntu 20.04+, and Debian 10+"
    exit 1
fi

print_status "Updating System Packages"
if [[ "$OS_NAME" == *"Amazon Linux"* ]]; then
    sudo dnf update -y
    sudo dnf groupinstall -y "Development Tools" || echo "⚠️ Development tools group not found, installing individual packages"
    sudo dnf install -y python3 python3-pip python3-devel git nginx htop wget unzip openssl firewalld cronie mysql || true
elif [[ "$OS_NAME" == *"Ubuntu"* ]] || [[ "$OS_NAME" == *"Debian"* ]]; then
    sudo apt update -y
    sudo apt install -y build-essential python3 python3-pip python3-dev python3-venv git nginx htop wget unzip openssl ufw cron mysql-client
fi

print_status "Configuring Firewall"
if [[ "$OS_NAME" == *"Amazon Linux"* ]]; then
    sudo systemctl start firewalld
    sudo systemctl enable firewalld
    sudo firewall-cmd --permanent --add-service=ssh
    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --permanent --add-service=https
    sudo firewall-cmd --reload
else
    sudo ufw allow OpenSSH
    sudo ufw allow 'Nginx Full'
    sudo ufw --force enable
fi

print_status "Creating Application User and Directories"
sudo useradd -m -s /bin/bash docuspa || echo "User docuspa already exists"
sudo mkdir -p /opt/docuspa
sudo mkdir -p /var/log/docuspa
sudo chown -R docuspa:docuspa /opt/docuspa
sudo chown -R docuspa:docuspa /var/log/docuspa

print_status "Setting Up Application (as docuspa user)"
sudo -u docuspa bash << 'EOF'
set -e
cd /opt/docuspa

echo "📥 Cloning/updating DocuSpa repository..."
if [ ! -d ".git" ]; then
    git clone https://github.com/Will-Pike/DocuSpa.git .
else
    echo "Repository exists, pulling latest changes..."
    git fetch origin
    git reset --hard origin/main
    git clean -fd
fi

echo "🐍 Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

echo "📦 Installing Python dependencies..."
pip install --upgrade pip wheel setuptools

# Install requirements with error handling
echo "Installing from requirements.txt..."
pip install -r requirements.txt

# Install production server
pip install gunicorn uvicorn[standard]

# Install specific versions of critical auth packages to avoid compatibility issues
echo "🔒 Installing critical authentication packages..."
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

echo "✅ Application setup completed successfully"
EOF

print_status "Creating Production Environment Configuration"
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa

# Create .env file with production settings
cat > .env << 'ENVEOF'
# DocuSpa Production Configuration
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

echo "✅ Environment configuration created"
EOF

print_status "Creating Systemd Service"
sudo tee /etc/systemd/system/docuspa.service > /dev/null << 'EOF'
[Unit]
Description=DocuSpa FastAPI Application
After=network.target
Wants=network.target

[Service]
Type=simple
User=docuspa
Group=docuspa
WorkingDirectory=/opt/docuspa
Environment="PATH=/opt/docuspa/venv/bin"
ExecStart=/opt/docuspa/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4
ExecReload=/bin/kill -HUP $MAINPID
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=docuspa

[Install]
WantedBy=multi-user.target
EOF

print_status "Creating Nginx Configuration"
sudo tee /etc/nginx/sites-available/docuspa.conf > /dev/null << 'EOF' 2>/dev/null || sudo tee /etc/nginx/conf.d/docuspa.conf > /dev/null << 'EOF'
# Rate limiting zones
limit_req_zone $binary_remote_addr zone=auth:10m rate=5r/m;
limit_req_zone $binary_remote_addr zone=api:10m rate=30r/m;
limit_req_zone $binary_remote_addr zone=general:10m rate=100r/m;

# Upstream backend
upstream docuspa_backend {
    server 127.0.0.1:8000 fail_timeout=30s max_fails=3;
    keepalive 32;
}

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private auth;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # Static files
    location /static/ {
        alias /opt/docuspa/static/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # Health check endpoint
    location /health {
        proxy_pass http://docuspa_backend;
        access_log off;
    }

    # Authentication endpoints (stricter rate limiting)
    location ~* ^/(auth|login|logout|register) {
        limit_req zone=auth burst=10 nodelay;
        limit_req_status 429;
        
        proxy_pass http://docuspa_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }

    # API endpoints (moderate rate limiting)
    location ~* ^/(api|admin) {
        limit_req zone=api burst=50 nodelay;
        limit_req_status 429;
        
        proxy_pass http://docuspa_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }

    # Main application
    location / {
        limit_req zone=general burst=200 nodelay;
        limit_req_status 429;
        
        proxy_pass http://docuspa_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
}
EOF

# Enable nginx site on Ubuntu/Debian
if [[ "$OS_NAME" == *"Ubuntu"* ]] || [[ "$OS_NAME" == *"Debian"* ]]; then
    sudo ln -sf /etc/nginx/sites-available/docuspa.conf /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
fi

print_status "Testing Nginx Configuration"
sudo nginx -t

print_status "Creating Admin User"
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa
source venv/bin/activate

echo "🔑 Creating admin user..."
python3 -c "
import sys
sys.path.append('/opt/docuspa')

try:
    from app.database import SessionLocal
    from app.models import User
    from app.services.auth import get_password_hash
    
    # Create database session
    db = SessionLocal()
    
    # Check if admin user exists
    admin_user = db.query(User).filter(User.email == 'admin@docuspa.com').first()
    
    if admin_user:
        print('✅ Admin user already exists')
    else:
        # Create admin user
        hashed_password = get_password_hash('admin123')
        admin_user = User(
            email='admin@docuspa.com',
            name='Admin User',
            hashed_password=hashed_password,
            is_active=True
        )
        db.add(admin_user)
        db.commit()
        print('✅ Admin user created successfully')
        print('   Email: admin@docuspa.com')
        print('   Password: admin123')
        
    db.close()
    
except Exception as e:
    print(f'⚠️ Admin user creation error: {e}')
    print('Admin user will need to be created manually after deployment')
"
EOF

print_status "Setting Up Log Rotation"
sudo tee /etc/logrotate.d/docuspa > /dev/null << 'EOF'
/var/log/docuspa/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 docuspa docuspa
    postrotate
        systemctl reload docuspa
    endscript
}
EOF

print_status "Enabling and Starting Services"
sudo systemctl daemon-reload
sudo systemctl enable docuspa
sudo systemctl enable nginx

# Stop any existing services
sudo systemctl stop docuspa 2>/dev/null || true
sudo systemctl stop nginx 2>/dev/null || true

# Start services
sudo systemctl start docuspa
sudo systemctl start nginx

# Wait a moment for services to start
sleep 5

print_status "Service Status Check"
echo "DocuSpa Service Status:"
sudo systemctl status docuspa --no-pager -l || true
echo ""
echo "Nginx Service Status:"
sudo systemctl status nginx --no-pager -l || true

print_status "Running Health Checks"
# Test if services are responding
sleep 3

echo "🔍 Testing application health..."
if curl -f -s http://localhost:8000/health > /dev/null 2>&1; then
    echo "✅ DocuSpa application is responding"
else
    echo "⚠️ DocuSpa application health check failed"
    echo "Checking application logs:"
    sudo journalctl -u docuspa --no-pager -n 20
fi

echo ""
echo "🔍 Testing nginx proxy..."
if curl -f -s http://localhost/ > /dev/null 2>&1; then
    echo "✅ Nginx proxy is working"
else
    echo "⚠️ Nginx proxy test failed"
fi

# Get public IP
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "Unable to detect")

print_status "Deployment Summary"
echo "🎉 DocuSpa deployment completed!"
echo ""
echo "📋 Service Status:"
echo "   • DocuSpa: $(sudo systemctl is-active docuspa)"
echo "   • Nginx: $(sudo systemctl is-active nginx)"
echo ""
echo "📡 Network Information:"
echo "   • Public IP: $PUBLIC_IP"
echo "   • Local IP: $(hostname -I | awk '{print $1}')"
echo ""
echo "🔐 Default Admin Credentials:"
echo "   • Email: admin@docuspa.com"
echo "   • Password: admin123"
echo ""
echo "🌐 Access Your Application:"
echo "   • URL: http://$PUBLIC_IP"
echo "   • Login: http://$PUBLIC_IP/login"
echo ""
echo "🔧 Useful Commands:"
echo "   • View logs: sudo journalctl -u docuspa -f"
echo "   • Restart app: sudo systemctl restart docuspa"
echo "   • Update app: cd /opt/docuspa && sudo -u docuspa git pull && sudo systemctl restart docuspa"
echo "   • Check status: sudo systemctl status docuspa nginx"
echo ""
echo "🔍 Troubleshooting:"
echo "   • If login fails, check logs: sudo journalctl -u docuspa -n 50"
echo "   • If 502 error, check app status: sudo systemctl status docuspa"
echo "   • Test direct app: curl http://localhost:8000/health"
echo ""

# Final verification
if sudo systemctl is-active --quiet docuspa && sudo systemctl is-active --quiet nginx; then
    echo "✅ Deployment successful! DocuSpa is running at http://$PUBLIC_IP"
else
    echo "⚠️ Deployment completed with warnings. Check service status above."
fi

echo ""
echo "$(date): Deployment process completed"
echo "=============================================="