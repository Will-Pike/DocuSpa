#!/bin/bash

# DocuSpa EC2 Deployment Script
# This script sets up DocuSpa on a fresh Ubuntu EC2 instance

set -e  # Exit on any error

echo "🚀 Starting DocuSpa EC2 deployment..."

# Update system packages
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install essential packages
echo "🔧 Installing essential packages..."
sudo apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    git \
    nginx \
    supervisor \
    htop \
    curl \
    wget \
    unzip \
    mysql-client \
    certbot \
    python3-certbot-nginx

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
sudo tee /etc/nginx/sites-available/docuspa > /dev/null << 'EOF'
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;  # Replace with your actual domain
    
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

    # Main application
    location / {
        proxy_pass http://127.0.0.1:8000;
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

    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:8000/health;
        access_log off;
    }
}
EOF

# Enable nginx site
echo "🔗 Enabling nginx site..."
sudo ln -sf /etc/nginx/sites-available/docuspa /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

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

# Set up firewall
echo "🔥 Configuring firewall..."
sudo ufw --force enable
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw allow 80
sudo ufw allow 443

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