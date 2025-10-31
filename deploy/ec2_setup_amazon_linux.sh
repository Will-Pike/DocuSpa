#!/bin/bash

# DocuSpa EC2 Deployment Script - Amazon Linux Version
# This script sets up DocuSpa on a fresh Amazon Linux 2023 EC2 instance

set -e  # Exit on any error

echo "🚀 Starting DocuSpa EC2 deployment (Amazon Linux)..."

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
fi

echo "📋 Detected OS: $OS $VER"

# Update system packages
echo "📦 Updating system packages..."
sudo dnf update -y

# Install essential packages
echo "🔧 Installing essential packages..."
sudo dnf groupinstall -y "Development Tools"

# Install packages one by one to handle any that might not be available
echo "📦 Installing core packages..."
sudo dnf install -y \
    python3 \
    python3-pip \
    python3-devel \
    git \
    nginx \
    htop \
    curl \
    wget \
    unzip \
    openssl \
    firewalld \
    cronie

# Install certbot and related packages
echo "🔒 Installing certbot..."
sudo dnf install -y certbot python3-certbot-nginx || echo "⚠️ Certbot installation failed, will skip SSL setup"

# Install MySQL client
echo "🗄️ Installing MySQL client..."
sudo dnf install -y mysql || echo "⚠️ MySQL client installation failed"

# Start and enable firewalld
echo "🔥 Configuring firewall..."
sudo systemctl start firewalld
sudo systemctl enable firewalld

# Configure firewall rules
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload

# Create application user
echo "👤 Creating application user..."
sudo useradd -m -s /bin/bash docuspa || echo "User already exists"

# Create application directories
echo "📁 Creating application directories..."
sudo mkdir -p /opt/docuspa
sudo mkdir -p /var/log/docuspa
sudo chown -R docuspa:docuspa /opt/docuspa
sudo chown -R docuspa:docuspa /var/log/docuspa

# Switch to docuspa user for app setup
echo "🔄 Setting up application as docuspa user..."
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa

# Clone the repository
echo "📥 Cloning DocuSpa repository..."
if [ ! -d ".git" ]; then
    git clone https://github.com/Will-Pike/DocuSpa.git .
else
    git pull origin main
fi

# Create Python virtual environment
echo "🐍 Creating Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Upgrade pip and install dependencies
echo "📦 Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Install additional production dependencies
pip install gunicorn uvicorn[standard]

echo "✅ Application setup completed as docuspa user"
EOF

# Create production environment file
echo "⚙️ Creating production environment file..."
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

echo "✅ Environment file created"
EOF

# Create systemd service file
echo "🔧 Creating systemd service..."
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
ExecStart=/opt/docuspa/venv/bin/python main.py
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

# Create nginx configuration
echo "🌐 Creating nginx configuration..."
sudo tee /etc/nginx/conf.d/docuspa.conf > /dev/null << 'EOF'
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
    listen 80;
    server_name _;  # Replace with your actual domain
    
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
    gzip_proxied expired no-cache no-store private must-revalidate;
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

# Test nginx configuration
echo "🧪 Testing nginx configuration..."
sudo nginx -t

# Create log rotation configuration
echo "📝 Setting up log rotation..."
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

# Enable and start services
echo "🚦 Enabling and starting services..."
sudo systemctl daemon-reload
sudo systemctl enable docuspa
sudo systemctl enable nginx

# Start services
sudo systemctl start docuspa
sudo systemctl start nginx

# Check service status
echo "📊 Checking service status..."
sudo systemctl status docuspa --no-pager -l
sudo systemctl status nginx --no-pager -l

# Display final information
echo ""
echo "🎉 DocuSpa deployment completed!"
echo ""
echo "📋 Service Status:"
echo "   • DocuSpa: $(sudo systemctl is-active docuspa)"
echo "   • Nginx: $(sudo systemctl is-active nginx)"
echo ""
echo "📡 Network Information:"
echo "   • Public IP: $(curl -s ifconfig.me || echo 'Unable to detect')"
echo "   • Local IP: $(hostname -I | awk '{print $1}')"
echo ""
echo "🔧 Useful Commands:"
echo "   • View logs: sudo journalctl -u docuspa -f"
echo "   • Restart app: sudo systemctl restart docuspa"
echo "   • Update app: cd /opt/docuspa && sudo -u docuspa git pull && sudo systemctl restart docuspa"
echo ""
echo "🌐 Next Steps:"
echo "   1. Point your domain to this server's public IP"
echo "   2. Update nginx config with your actual domain name"
echo "   3. Set up SSL certificate: sudo certbot --nginx -d your-domain.com"
echo "   4. Test the application at http://$(curl -s ifconfig.me || echo 'YOUR-PUBLIC-IP')"
echo ""
echo "✅ Deployment complete!"