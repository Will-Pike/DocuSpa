#!/bin/bash

# DocuSpa Auto-Deployment Script
# Automatically detects the OS and runs the appropriate deployment script

set -e

echo "🚀 DocuSpa Auto-Deployment Script"
echo "=================================="

# Detect the operating system
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
    
    echo "📋 Detected OS: $OS $VER"
    
    # Determine which deployment script to use
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        echo "🐧 Using Ubuntu/Debian deployment script..."
        SCRIPT_URL="https://raw.githubusercontent.com/Will-Pike/DocuSpa/main/deploy/ec2_setup.sh"
        SCRIPT_NAME="ec2_setup.sh"
    elif [[ "$OS" == *"Amazon Linux"* ]] || [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
        echo "🔴 Using Amazon Linux/RHEL deployment script..."
        SCRIPT_URL="https://raw.githubusercontent.com/Will-Pike/DocuSpa/main/deploy/ec2_setup_amazon_linux.sh"
        SCRIPT_NAME="ec2_setup_amazon_linux.sh"
    else
        echo "❌ Unsupported operating system: $OS"
        echo "Supported systems:"
        echo "  • Ubuntu 20.04+"
        echo "  • Debian 10+"
        echo "  • Amazon Linux 2023"
        echo "  • CentOS 8+"
        echo "  • RHEL 8+"
        exit 1
    fi
else
    echo "❌ Cannot detect operating system"
    exit 1
fi

# Download the appropriate deployment script
echo "📥 Downloading deployment script..."
wget -O "$SCRIPT_NAME" "$SCRIPT_URL"

# Make it executable
chmod +x "$SCRIPT_NAME"

echo "✅ Downloaded $SCRIPT_NAME"
echo ""
echo "🚀 Starting deployment..."
echo "========================="

# Run the deployment script
./"$SCRIPT_NAME"