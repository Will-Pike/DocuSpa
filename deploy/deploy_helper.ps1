# DocuSpa EC2 Instance Connect Deployment Helper
# This script helps you deploy DocuSpa to EC2 using AWS Instance Connect

param(
    [Parameter(Mandatory=$true)]
    [string]$InstanceId,
    
    [string]$Region = "us-east-1"
)

Write-Host "🚀 DocuSpa EC2 Instance Connect Deployment Helper" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green

# Check if AWS CLI is installed
try {
    aws --version | Out-Null
    Write-Host "✅ AWS CLI detected" -ForegroundColor Green
} catch {
    Write-Host "❌ AWS CLI not found. Please install AWS CLI first:" -ForegroundColor Red
    Write-Host "https://aws.amazon.com/cli/" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "📋 Deployment Information:" -ForegroundColor Cyan
Write-Host "   Instance ID: $InstanceId" -ForegroundColor White
Write-Host "   Region: $Region" -ForegroundColor White
Write-Host ""

# Get instance information
Write-Host "🔍 Getting instance information..." -ForegroundColor Yellow
try {
    $instanceInfo = aws ec2 describe-instances --instance-ids $InstanceId --region $Region --query 'Reservations[0].Instances[0]' 2>$null | ConvertFrom-Json
    
    if ($instanceInfo) {
        $instanceState = $instanceInfo.State.Name
        $publicIP = $instanceInfo.PublicIpAddress
        $platform = $instanceInfo.PlatformDetails
        
        Write-Host "✅ Instance found!" -ForegroundColor Green
        Write-Host "   State: $instanceState" -ForegroundColor White
        Write-Host "   Platform: $platform" -ForegroundColor White
        Write-Host "   Public IP: $publicIP" -ForegroundColor White
        
        if ($instanceState -ne "running") {
            Write-Host "⚠️ Instance is not running. Current state: $instanceState" -ForegroundColor Yellow
            Write-Host "Please start the instance and try again." -ForegroundColor White
            exit 1
        }
    } else {
        Write-Host "❌ Instance not found or no permissions" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "⚠️ Could not get instance information. Continuing anyway..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "📝 Deployment Script Instructions:" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Green

Write-Host ""
Write-Host "🔑 Step 1: Connect to your instance" -ForegroundColor Yellow
Write-Host "Choose one of these methods:" -ForegroundColor White
Write-Host ""
Write-Host "Method A - AWS Console (Recommended):" -ForegroundColor Cyan
Write-Host "1. Go to AWS Console > EC2 > Instances" -ForegroundColor White
Write-Host "2. Select instance: $InstanceId" -ForegroundColor White
Write-Host "3. Click 'Connect'" -ForegroundColor White
Write-Host "4. Choose 'EC2 Instance Connect'" -ForegroundColor White
Write-Host "5. Click 'Connect' to open browser terminal" -ForegroundColor White
Write-Host ""
Write-Host "Method B - AWS CLI Session Manager:" -ForegroundColor Cyan
Write-Host "aws ssm start-session --target $InstanceId --region $Region" -ForegroundColor White

Write-Host ""
Write-Host "🚀 Step 2: Run the deployment script" -ForegroundColor Yellow
Write-Host "Copy and paste this command in your EC2 terminal:" -ForegroundColor White
Write-Host ""
Write-Host "# Download and run the deployment script" -ForegroundColor Green
Write-Host "curl -fsSL https://raw.githubusercontent.com/Will-Pike/DocuSpa/main/deploy/instance_connect_deploy.sh | bash" -ForegroundColor Cyan
Write-Host ""
Write-Host "OR manually copy the script:" -ForegroundColor Green
Write-Host "1. Create the script file:" -ForegroundColor White
Write-Host "   nano deploy_docuspa.sh" -ForegroundColor Cyan
Write-Host "2. Copy the entire script content from deploy/instance_connect_deploy.sh" -ForegroundColor White
Write-Host "3. Make it executable and run:" -ForegroundColor White
Write-Host "   chmod +x deploy_docuspa.sh" -ForegroundColor Cyan
Write-Host "   ./deploy_docuspa.sh" -ForegroundColor Cyan

Write-Host ""
Write-Host "📋 What the script does:" -ForegroundColor Yellow
Write-Host "✅ Updates system packages" -ForegroundColor Green
Write-Host "✅ Installs Python, Git, Nginx, and dependencies" -ForegroundColor Green
Write-Host "✅ Creates application user and directories" -ForegroundColor Green
Write-Host "✅ Clones DocuSpa from GitHub" -ForegroundColor Green
Write-Host "✅ Sets up Python virtual environment" -ForegroundColor Green
Write-Host "✅ Installs all required packages with authentication fixes" -ForegroundColor Green
Write-Host "✅ Creates production configuration" -ForegroundColor Green
Write-Host "✅ Sets up systemd service" -ForegroundColor Green
Write-Host "✅ Configures nginx reverse proxy" -ForegroundColor Green
Write-Host "✅ Creates admin user (admin@docuspa.com / admin123)" -ForegroundColor Green
Write-Host "✅ Starts all services" -ForegroundColor Green
Write-Host "✅ Runs health checks" -ForegroundColor Green

Write-Host ""
Write-Host "⏱️ Expected deployment time: 5-10 minutes" -ForegroundColor Yellow

Write-Host ""
Write-Host "🔍 After deployment, you should see:" -ForegroundColor Yellow
Write-Host "✅ DocuSpa running at: http://$publicIP" -ForegroundColor Green
Write-Host "✅ Login page: http://$publicIP/login" -ForegroundColor Green
Write-Host "✅ Admin credentials: admin@docuspa.com / admin123" -ForegroundColor Green

Write-Host ""
Write-Host "🛠️ Troubleshooting commands (run on EC2):" -ForegroundColor Yellow
Write-Host "# Check service status" -ForegroundColor Green
Write-Host "sudo systemctl status docuspa nginx" -ForegroundColor Cyan
Write-Host ""
Write-Host "# View application logs" -ForegroundColor Green
Write-Host "sudo journalctl -u docuspa -f" -ForegroundColor Cyan
Write-Host ""
Write-Host "# Test application directly" -ForegroundColor Green
Write-Host "curl http://localhost:8000/health" -ForegroundColor Cyan
Write-Host ""
Write-Host "# Restart services if needed" -ForegroundColor Green
Write-Host "sudo systemctl restart docuspa nginx" -ForegroundColor Cyan

Write-Host ""
Write-Host "🎯 Ready to deploy? Connect to your instance and run the script!" -ForegroundColor Green
Write-Host "Instance ID: $InstanceId" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow
if ($publicIP) {
    Write-Host "Your app will be available at: http://$publicIP" -ForegroundColor Green
}

Write-Host ""
Write-Host "💡 Pro tip: Keep this PowerShell window open for reference!" -ForegroundColor Cyan