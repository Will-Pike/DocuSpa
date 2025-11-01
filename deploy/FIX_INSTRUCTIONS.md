# DocuSpa Deployment Fix Instructions

## Current Issue
The DocuSpa application is failing to start due to ImportError issues with the authentication service. The service can't find the required functions (`create_access_token`, `verify_token`) from `app.services.auth`.

## Solution Overview
I've created several scripts to fix this issue:

1. **fix_auth_deployment.sh** - Fixes the authentication dependencies and restarts the service
2. **verify_deployment.sh** - Verifies that everything is working correctly
3. **fix_deployment.ps1** - PowerShell script to run the fixes remotely

## Quick Fix Steps

### Option 1: Using PowerShell Script (Recommended)
```powershell
# Navigate to the DocuSpa directory
cd c:\Code\DocuSpa

# Run the fix script (you'll need your EC2 key file path)
.\deploy\fix_deployment.ps1 -KeyPath "path\to\your\key.pem" -ServerIP "34.207.84.187"
```

### Option 2: Manual SSH Connection
If you have your SSH key file, connect manually:

```powershell
# Connect to the server
ssh -i "path\to\your\key.pem" ec2-user@34.207.84.187

# Upload and run the fix script
sudo wget https://raw.githubusercontent.com/yourusername/DocuSpa/main/deploy/fix_auth_deployment.sh -O /tmp/fix_auth_deployment.sh
sudo chmod +x /tmp/fix_auth_deployment.sh
sudo /tmp/fix_auth_deployment.sh
```

### Option 3: Using AWS Systems Manager (if enabled)
You can also use AWS Systems Manager Session Manager if it's enabled on your instance.

## What the Fix Does

1. **Stops the DocuSpa service** to prevent conflicts
2. **Reinstalls critical dependencies** with force reinstall:
   - passlib[bcrypt]
   - python-jose[cryptography] 
   - bcrypt
3. **Tests imports** to ensure all auth functions are available
4. **Tests bcrypt functionality** specifically
5. **Pulls latest code** to ensure correct auth.py file
6. **Restarts the service** and verifies it's working

## After the Fix

The verification script will check:
- ✅ Service status (DocuSpa and Nginx)
- ✅ API connectivity 
- ✅ Auth service functionality
- ✅ Database connectivity
- ✅ Public endpoint access

## Test URLs After Fix
- Health check: http://34.207.84.187/
- Auth test: http://34.207.84.187/auth/test  
- Login page: http://34.207.84.187/login

## If Issues Persist

Check the service logs:
```bash
sudo journalctl -u docuspa -f
```

Common issues and solutions:
- **Port 8000 not accessible**: Check security group allows inbound HTTP (port 80)
- **502 Bad Gateway**: DocuSpa service not running, check logs
- **Database connection issues**: Verify RDS credentials in /opt/docuspa/.env

## Next Steps After Fix
1. Test the login functionality with existing admin users
2. Verify document uploads work correctly  
3. Set up SSL certificate for production use
4. Configure domain name if available

Let me know if you need the SSH key file or have any questions!
