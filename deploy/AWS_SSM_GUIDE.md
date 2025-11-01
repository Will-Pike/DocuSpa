# AWS Systems Manager Connection Guide

## No SSH Key? No Problem!

Since you didn't create an SSH key pair, you can use **AWS Systems Manager** to connect to your EC2 instance instead.

## Quick Setup Steps

### 1. Find Your EC2 Instance ID
1. Go to **AWS Console > EC2 > Instances**
2. Find your DocuSpa instance 
3. Copy the **Instance ID** (looks like `i-0123456789abcdef0`)

### 2. Install AWS CLI (if not already installed)
```powershell
# Download and install AWS CLI
# Go to: https://aws.amazon.com/cli/
# Or use chocolatey:
choco install awscli
```

### 3. Configure AWS CLI
```powershell
aws configure
# Enter your:
# - AWS Access Key ID
# - AWS Secret Access Key  
# - Default region (e.g., us-east-1)
# - Default output format (json)
```

### 4. Run the Fix Script
```powershell
cd c:\Code\DocuSpa

# Replace i-1234567890abcdef0 with your actual instance ID
.\deploy\fix_deployment_aws.ps1 -InstanceId "i-1234567890abcdef0" -Region "us-east-1"
```

## Alternative: Use AWS Console

If AWS CLI doesn't work, you can use the web console:

### 1. Connect via Session Manager
1. Go to **AWS Console > EC2 > Instances**
2. Select your DocuSpa instance
3. Click **Connect**
4. Choose **Session Manager** tab
5. Click **Connect**

### 2. Run These Commands in the Browser Terminal

```bash
# Stop the service
sudo systemctl stop docuspa

# Fix Python dependencies
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa
source venv/bin/activate
pip install --force-reinstall passlib[bcrypt]==1.7.4
pip install --force-reinstall python-jose[cryptography]==3.3.0
pip install --force-reinstall bcrypt
EOF

# Test imports
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa
source venv/bin/activate
python3 -c "
import sys
sys.path.append('/opt/docuspa')
try:
    from app.services.auth import verify_password, create_access_token, verify_token, get_password_hash
    print('✅ All auth functions available')
except ImportError as e:
    print(f'❌ Import error: {e}')
"
EOF

# Start the service
sudo systemctl start docuspa

# Check status
sudo systemctl status docuspa

# Test API
curl -s http://localhost:8000/auth/test
```

## Troubleshooting

### If Session Manager doesn't work:
1. **Check IAM Role**: Your EC2 instance needs the `AmazonSSMManagedInstanceCore` policy
2. **Check SSM Agent**: Should be running (it's installed by default on Amazon Linux 2023)
3. **Check Region**: Make sure you're in the correct AWS region

### If the fix doesn't work:
1. **Check logs**: `sudo journalctl -u docuspa -f`
2. **Check service status**: `sudo systemctl status docuspa`
3. **Manual verification**: Test each import individually

## Expected Results After Fix

✅ **Service Status**: DocuSpa should be "active (running)"  
✅ **API Test**: http://34.207.84.187/auth/test should return `{"status": "ok"}`  
✅ **Login Page**: http://34.207.84.187/login should load  
✅ **Health Check**: http://34.207.84.187/ should respond  

## Need Your Instance ID?

Run this to find all your EC2 instances:
```powershell
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]' --output table
```

Your DocuSpa instance should be in the list!
