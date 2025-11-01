#!/bin/bash

# DocuSpa Deployment Verification Script
# This script verifies that all components of DocuSpa are working correctly

echo "🔍 DocuSpa Deployment Verification"
echo "=================================="

# Check if services are running
echo ""
echo "📊 Service Status Check:"
docuspa_status=$(sudo systemctl is-active docuspa)
nginx_status=$(sudo systemctl is-active nginx)

echo "   • DocuSpa Service: $docuspa_status"
echo "   • Nginx Service: $nginx_status"

if [ "$docuspa_status" != "active" ]; then
    echo "❌ DocuSpa service is not running!"
    echo "Last 20 lines from service logs:"
    sudo journalctl -u docuspa -n 20 --no-pager
    exit 1
fi

if [ "$nginx_status" != "active" ]; then
    echo "❌ Nginx service is not running!"
    exit 1
fi

# Test local API connectivity
echo ""
echo "🧪 API Connectivity Tests:"

# Test health endpoint
echo -n "   • Health endpoint: "
if curl -s -f http://localhost:8000/ > /dev/null 2>&1; then
    echo "✅ OK"
else
    echo "❌ FAILED"
fi

# Test auth service
echo -n "   • Auth service test: "
auth_response=$(curl -s http://localhost:8000/auth/test 2>/dev/null)
if echo "$auth_response" | grep -q '"status": "ok"'; then
    echo "✅ OK"
else
    echo "❌ FAILED"
    echo "      Response: $auth_response"
fi

# Test database connectivity
echo -n "   • Database connectivity: "
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa
source venv/bin/activate
python3 -c "
import sys
sys.path.append('/opt/docuspa')
try:
    from app.database import get_db
    from app.models.user import User
    from sqlalchemy.orm import Session
    
    db = next(get_db())
    user_count = db.query(User).count()
    print(f'✅ OK ({user_count} users in database)')
except Exception as e:
    print(f'❌ FAILED: {e}')
"
EOF

# Test through nginx
echo ""
echo "🌐 Nginx Proxy Tests:"
public_ip=$(curl -s ifconfig.me 2>/dev/null || echo "localhost")

echo -n "   • Public endpoint: "
if curl -s -f http://$public_ip/ > /dev/null 2>&1; then
    echo "✅ OK"
else
    echo "❌ FAILED - Check security group settings"
fi

# Port checks
echo ""
echo "🔌 Port Status:"
echo "   • Port 8000 (DocuSpa): $(sudo netstat -tlnp | grep :8000 | wc -l) listener(s)"
echo "   • Port 80 (Nginx): $(sudo netstat -tlnp | grep :80 | wc -l) listener(s)"

# Disk space check
echo ""
echo "💾 System Resources:"
echo "   • Disk usage: $(df -h /opt | tail -1 | awk '{print $5}') used"
echo "   • Memory usage: $(free -h | grep Mem | awk '{print $3 "/" $2}')"

# Log file sizes
echo ""
echo "📝 Log Information:"
if [ -f /var/log/docuspa/app.log ]; then
    echo "   • App log size: $(du -h /var/log/docuspa/app.log | cut -f1)"
else
    echo "   • App log: Not found (using systemd journal)"
fi

echo "   • Journal entries: $(sudo journalctl -u docuspa --since="1 hour ago" | wc -l) in last hour"

echo ""
echo "🎯 Test URLs:"
echo "   • Health: http://$public_ip/"
echo "   • Auth Test: http://$public_ip/auth/test"
echo "   • Login Page: http://$public_ip/login"

echo ""
if [ "$docuspa_status" = "active" ] && curl -s -f http://localhost:8000/ > /dev/null 2>&1; then
    echo "🎉 ✅ Deployment verification PASSED!"
else
    echo "❌ Deployment verification FAILED!"
    exit 1
fi
