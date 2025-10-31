# DocuSpa AWS Deployment Files

This directory contains everything you need to deploy DocuSpa on AWS EC2.

## Quick Start

1. **Launch EC2 Instance** (see AWS_DEPLOYMENT_GUIDE.md for details)
2. **Connect to your instance**:
   ```bash
   ssh -i "your-key.pem" ubuntu@your-elastic-ip
   ```
3. **Download and run deployment script**:
   ```bash
   wget https://raw.githubusercontent.com/Will-Pike/DocuSpa/main/deploy/ec2_setup.sh
   chmod +x ec2_setup.sh
   sudo ./ec2_setup.sh
   ```

## Files Overview

| File | Purpose | Usage |
|------|---------|-------|
| `AWS_DEPLOYMENT_GUIDE.md` | Complete deployment guide | Read first for full instructions |
| `ec2_setup.sh` | Automated deployment script | Run on fresh EC2 instance |
| `.env.production` | Production environment template | Configure for your environment |
| `docuspa.service` | Systemd service configuration | Automatically installed by script |
| `nginx.conf` | Nginx reverse proxy config | Production-ready with SSL support |
| `health-check.sh` | Application monitoring script | Run periodically to check health |
| `update.sh` | Safe application update script | Update with zero downtime |

## Post-Deployment Setup

### 1. Domain Configuration
Update nginx configuration with your domain:
```bash
sudo nano /etc/nginx/sites-available/docuspa
# Replace 'your-domain.com' with actual domain
sudo systemctl restart nginx
```

### 2. SSL Certificate
```bash
sudo certbot --nginx -d your-domain.com -d www.your-domain.com
```

### 3. Set Up Monitoring
```bash
# Add health check to crontab
sudo crontab -e
# Add: */5 * * * * /opt/docuspa/deploy/health-check.sh >/dev/null 2>&1
```

## Management Commands

### Service Management
```bash
# Check status
sudo systemctl status docuspa
sudo systemctl status nginx

# View logs
sudo journalctl -u docuspa -f
sudo tail -f /var/log/nginx/docuspa_access.log

# Restart services
sudo systemctl restart docuspa
sudo systemctl restart nginx
```

### Application Updates
```bash
# Safe update with automatic rollback on failure
sudo /opt/docuspa/deploy/update.sh

# Manual update
cd /opt/docuspa
sudo -u docuspa git pull origin main
sudo systemctl restart docuspa
```

### Health Monitoring
```bash
# Run health check
sudo /opt/docuspa/deploy/health-check.sh

# Check application health endpoint
curl http://localhost:8000/health
```

## File Locations

- **Application**: `/opt/docuspa/`
- **Logs**: `/var/log/docuspa/`
- **Service Config**: `/etc/systemd/system/docuspa.service`
- **Nginx Config**: `/etc/nginx/sites-available/docuspa`
- **Environment**: `/opt/docuspa/.env`
- **Backups**: `/opt/docuspa-backups/`

## Security Features

The deployment includes:
- ✅ Firewall configuration (UFW)
- ✅ SSL/TLS with Let's Encrypt
- ✅ Security headers in Nginx
- ✅ Rate limiting
- ✅ Service isolation with systemd
- ✅ Regular log rotation
- ✅ Automatic backups

## Troubleshooting

### Application Won't Start
```bash
# Check service status
sudo systemctl status docuspa

# Check logs
sudo journalctl -u docuspa -n 50

# Test application directly
cd /opt/docuspa
sudo -u docuspa bash -c "source venv/bin/activate && python main.py"
```

### Database Connection Issues
```bash
# Test database connectivity
mysql -h docuspa-db.cvy4mgkesrso.us-east-2.rds.amazonaws.com -u admin -p docuspa-db

# Check RDS security group allows EC2 connections
```

### SSL Certificate Issues
```bash
# Renew certificate
sudo certbot renew

# Test nginx config
sudo nginx -t

# Check certificate status
sudo certbot certificates
```

## Performance Optimization

### For Production Load
- Upgrade to larger EC2 instance (t3.medium or t3.large)
- Add Application Load Balancer for multiple instances
- Use RDS Multi-AZ for database high availability
- Implement CloudFront CDN for static assets

### Monitoring Setup
- CloudWatch metrics for EC2 and RDS
- Set up alarms for high CPU, memory, disk usage
- Configure SNS notifications for alerts

## Backup Strategy

- **Application**: Automatic backups during updates
- **Database**: RDS automated backups (enabled)
- **Configuration**: Version controlled in Git

## Support

For deployment issues:
- Check the deployment logs
- Review the AWS_DEPLOYMENT_GUIDE.md
- Verify security group configurations
- Test database connectivity

The deployment is designed to be production-ready with security, monitoring, and maintenance features built in.