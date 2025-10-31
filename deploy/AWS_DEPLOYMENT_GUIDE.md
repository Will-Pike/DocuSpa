# DocuSpa AWS Deployment Guide

This guide will help you deploy DocuSpa on AWS EC2 with all necessary infrastructure components.

## Prerequisites

- AWS Account with appropriate permissions
- Domain name (recommended for production)
- Basic familiarity with AWS Console

## Step 1: Launch EC2 Instance

### Instance Configuration
- **AMI Options**:
  - **Ubuntu Server 22.04 LTS** (recommended)
  - **Amazon Linux 2023** (also supported)
- **Instance Type**: 
  - Development: `t3.micro` (1 vCPU, 1 GB RAM) - Free tier eligible
  - Production: `t3.small` or larger (2 vCPU, 2 GB RAM+)
- **Storage**: 20 GB gp3 SSD minimum (30 GB recommended)

### Key Pair
- Create a new key pair or use existing one
- Download the `.pem` file and keep it secure
- Set permissions: `chmod 400 your-key.pem`

## Step 2: Configure Security Groups

Create a new security group with the following rules:

### Inbound Rules
| Type  | Protocol | Port Range | Source    | Description          |
|-------|----------|------------|-----------|----------------------|
| SSH   | TCP      | 22         | Your IP   | SSH access           |
| HTTP  | TCP      | 80         | 0.0.0.0/0 | Web traffic          |
| HTTPS | TCP      | 443        | 0.0.0.0/0 | Secure web traffic   |

### Outbound Rules
- Allow all outbound traffic (default)

## Step 3: Elastic IP (Recommended)

1. Allocate an Elastic IP address
2. Associate it with your EC2 instance
3. This provides a static IP address for your domain

## Step 4: Connect to Your Instance

### Using SSH (Linux/Mac/Windows with WSL)
```bash
ssh -i "your-key.pem" ubuntu@your-elastic-ip
```

### Using AWS Session Manager (Alternative)
- No SSH key required
- Connect through AWS Console
- Requires SSM Agent (pre-installed on Ubuntu AMI)

## Step 5: Run Deployment Script

Once connected to your instance:

### Option A: Auto-detect OS (Recommended)
```bash
# Download auto-deployment script
wget https://raw.githubusercontent.com/Will-Pike/DocuSpa/main/deploy/auto_deploy.sh

# Make it executable and run
chmod +x auto_deploy.sh
sudo ./auto_deploy.sh
```

### Option B: Manual OS Selection

**For Ubuntu/Debian:**
```bash
wget https://raw.githubusercontent.com/Will-Pike/DocuSpa/main/deploy/ec2_setup.sh
chmod +x ec2_setup.sh
sudo ./ec2_setup.sh
```

**For Amazon Linux/RHEL/CentOS:**
```bash
wget https://raw.githubusercontent.com/Will-Pike/DocuSpa/main/deploy/ec2_setup_amazon_linux.sh
chmod +x ec2_setup_amazon_linux.sh
sudo ./ec2_setup_amazon_linux.sh
```

The script will:
- ✅ Install all required packages
- ✅ Set up Python virtual environment
- ✅ Clone and configure DocuSpa
- ✅ Create systemd service
- ✅ Configure Nginx reverse proxy
- ✅ Set up firewall rules
- ✅ Start all services

## Step 6: Domain Configuration (Optional but Recommended)

### DNS Setup
1. Point your domain's A record to your Elastic IP
2. Add www subdomain if desired

### SSL Certificate (Free with Let's Encrypt)
```bash
# Update nginx config with your domain
sudo nano /etc/nginx/sites-available/docuspa
# Replace 'your-domain.com' with your actual domain

# Restart nginx
sudo systemctl restart nginx

# Get SSL certificate
sudo certbot --nginx -d your-domain.com -d www.your-domain.com
```

## Step 7: Application Configuration

### Environment Variables
The deployment script creates a production `.env` file. You may need to update:

```bash
sudo -u docuspa nano /opt/docuspa/.env
```

Key settings to verify:
- Database connection (already configured for your RDS)
- ShareFile credentials (already configured)
- Domain-specific settings

### Restart after changes
```bash
sudo systemctl restart docuspa
```

## Step 8: Database Connectivity

Your RDS instance needs to allow connections from EC2:

1. **Security Group for RDS**:
   - Add inbound rule: MySQL/Aurora (port 3306)
   - Source: Your EC2 security group ID

2. **Test Connection**:
   ```bash
   mysql -h docuspa-db.cvy4mgkesrso.us-east-2.rds.amazonaws.com -u admin -p docuspa-db
   ```

## Monitoring and Maintenance

### Service Management
```bash
# Check service status
sudo systemctl status docuspa
sudo systemctl status nginx

# View logs
sudo journalctl -u docuspa -f
sudo tail -f /var/log/nginx/access.log

# Restart services
sudo systemctl restart docuspa
sudo systemctl restart nginx
```

### Application Updates
```bash
cd /opt/docuspa
sudo -u docuspa git pull origin main
sudo systemctl restart docuspa
```

### System Updates
```bash
sudo apt update && sudo apt upgrade -y
sudo reboot  # If kernel updates
```

## Cost Optimization

### EC2 Instance
- Use Reserved Instances for production (up to 75% savings)
- Consider Spot Instances for development (up to 90% savings)
- Monitor usage with CloudWatch

### Storage
- Use gp3 volumes (better price/performance than gp2)
- Clean up old logs regularly

### Data Transfer
- Use CloudFront CDN if serving global users
- Monitor bandwidth usage

## Security Best Practices

### Instance Security
- Keep system updated: `sudo apt update && sudo apt upgrade`
- Use fail2ban for SSH protection: `sudo apt install fail2ban`
- Regular security patches

### Application Security
- Use strong passwords for admin accounts
- Enable 2FA when implemented
- Regular database backups
- Monitor access logs

### Network Security
- Restrict SSH access to your IP only
- Use VPC with private subnets for production
- Enable CloudTrail for audit logging

## Backup Strategy

### Application Backup
```bash
# Create backup script
sudo crontab -e
# Add: 0 2 * * * /opt/docuspa/backup_app.sh
```

### Database Backup
- RDS automated backups (already enabled)
- Consider cross-region backup for disaster recovery

## Troubleshooting

### Common Issues

1. **Service won't start**:
   ```bash
   sudo journalctl -u docuspa -n 50
   ```

2. **Database connection failed**:
   - Check RDS security group
   - Verify credentials in .env
   - Test network connectivity

3. **Nginx errors**:
   ```bash
   sudo nginx -t
   sudo tail -f /var/log/nginx/error.log
   ```

### Performance Issues
- Monitor with htop: `htop`
- Check disk space: `df -h`
- Monitor memory: `free -h`

## Production Checklist

- [ ] EC2 instance running with Elastic IP
- [ ] Security groups properly configured
- [ ] Domain pointing to Elastic IP
- [ ] SSL certificate installed and working
- [ ] Database connectivity verified
- [ ] Application responding on domain
- [ ] Admin users can login
- [ ] ShareFile integration working
- [ ] Backup strategy implemented
- [ ] Monitoring alerts configured

## Support

For issues with:
- **AWS Infrastructure**: AWS Support or documentation
- **DocuSpa Application**: GitHub Issues or application logs
- **Domain/DNS**: Your domain registrar support

---

## Quick Deploy Commands Summary

```bash
# 1. Connect to EC2
ssh -i "your-key.pem" ubuntu@your-elastic-ip
# or: ssh -i "your-key.pem" ec2-user@your-elastic-ip  # for Amazon Linux

# 2. Download and run auto-deployment (detects OS automatically)
wget https://raw.githubusercontent.com/Will-Pike/DocuSpa/main/deploy/auto_deploy.sh
chmod +x auto_deploy.sh
sudo ./auto_deploy.sh

# 3. Configure domain (replace with your domain)
# Ubuntu: sudo nano /etc/nginx/sites-available/docuspa
# Amazon Linux: sudo nano /etc/nginx/conf.d/docuspa.conf
sudo systemctl restart nginx
sudo certbot --nginx -d your-domain.com

# 4. Test application
curl http://your-elastic-ip
```

Your DocuSpa application should now be running in production! 🚀