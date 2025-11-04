# DocuSpa ShareFile Fix - Manual Commands for Existing EC2 Instance

## Quick Fix Commands (run these on your EC2 server)

### 1. Stop the service
```bash
sudo systemctl stop docuspa
```

### 2. Update the code
```bash
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa
git pull origin main
EOF
```

### 3. Update Python dependencies (critical fix)
```bash
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa
source venv/bin/activate
pip install --force-reinstall "passlib[bcrypt]==1.7.4"
pip install --force-reinstall "python-jose[cryptography]==3.3.0" 
pip install --force-reinstall "bcrypt>=4.0.0"
pip install -r requirements.txt --upgrade
EOF
```

### 4. Test the authentication fix
```bash
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa
source venv/bin/activate
python3 -c "
from app.services.auth import verify_password, get_password_hash
test_hash = get_password_hash('test123')
result = verify_password('test123', test_hash)
print(f'Auth test result: {result}')
"
EOF
```

### 5. Start the service
```bash
sudo systemctl start docuspa
sudo systemctl status docuspa
```

### 6. Test the application
```bash
curl http://localhost:8000/health
```

## What This Fixes

The main issue is that your server has **outdated versions** of critical authentication packages:
- `passlib` - for password hashing
- `bcrypt` - for secure password encryption  
- `python-jose` - for JWT token handling

The ShareFile integration requires these packages to work correctly for user authentication and API access.

## One-Line Fix (Alternative)

If you prefer, download and run the automated fix script:

```bash
curl -fsSL https://raw.githubusercontent.com/Will-Pike/DocuSpa/main/deploy/fix_existing_sharefile.sh | sudo bash
```

## Expected Results

After the fix:
- ✅ Login should work properly
- ✅ ShareFile folders and files should be visible
- ✅ File downloads should work via server proxy
- ✅ No more authentication import errors

## Troubleshooting

If issues persist:

**Check logs:**
```bash
sudo journalctl -u docuspa -f
```

**Restart service:**
```bash
sudo systemctl restart docuspa
```

**Test authentication directly:**
```bash
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa
source venv/bin/activate
python3 -c "
try:
    from app.services.auth import verify_password, create_access_token, verify_token, get_password_hash
    print('✅ All auth functions loaded')
except Exception as e:
    print(f'❌ Error: {e}')
"
EOF
```