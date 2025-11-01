# DocuSpa Fix using AWS Systems Manager Run Command
# This script sends commands directly to the EC2 instance without SSH

param(
    [Parameter(Mandatory=$true)]
    [string]$InstanceId,
    
    [string]$Region = "us-east-1"
)

Write-Host "DocuSpa Fix via AWS Systems Manager Run Command" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

# Check if AWS CLI is installed
try {
    aws --version | Out-Null
    Write-Host "AWS CLI found" -ForegroundColor Green
} catch {
    Write-Host "AWS CLI not found. Please install AWS CLI first:" -ForegroundColor Red
    Write-Host "https://aws.amazon.com/cli/" -ForegroundColor Yellow
    exit 1
}

Write-Host "Instance ID: $InstanceId" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow

try {
    # Step 1: Stop DocuSpa service
    Write-Host "`nStep 1: Stopping DocuSpa service..." -ForegroundColor Cyan
    $StopCommand = "sudo systemctl stop docuspa"
    
    $CommandId = aws ssm send-command `
        --instance-ids $InstanceId `
        --document-name "AWS-RunShellScript" `
        --parameters "commands=['$StopCommand']" `
        --region $Region `
        --query 'Command.CommandId' `
        --output text

    if ($CommandId) {
        Write-Host "Command sent. Waiting for completion..." -ForegroundColor Yellow
        Start-Sleep 10
        
        $Result = aws ssm get-command-invocation `
            --command-id $CommandId `
            --instance-id $InstanceId `
            --region $Region `
            --query 'Status' `
            --output text
            
        Write-Host "Stop service result: $Result" -ForegroundColor Green
    }

    # Step 2: Fix Python dependencies
    Write-Host "`nStep 2: Fixing Python dependencies..." -ForegroundColor Cyan
    $FixCommand = @"
sudo -u docuspa bash << 'EOF'
cd /opt/docuspa
source venv/bin/activate
pip install --force-reinstall passlib[bcrypt]==1.7.4
pip install --force-reinstall python-jose[cryptography]==3.3.0
pip install --force-reinstall bcrypt
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
"@

    $CommandId = aws ssm send-command `
        --instance-ids $InstanceId `
        --document-name "AWS-RunShellScript" `
        --parameters "commands=['$FixCommand']" `
        --region $Region `
        --query 'Command.CommandId' `
        --output text

    if ($CommandId) {
        Write-Host "Fix command sent. Waiting for completion..." -ForegroundColor Yellow
        Start-Sleep 30
        
        $Output = aws ssm get-command-invocation `
            --command-id $CommandId `
            --instance-id $InstanceId `
            --region $Region `
            --query 'StandardOutputContent' `
            --output text
            
        Write-Host "Fix output:" -ForegroundColor Green
        Write-Host $Output -ForegroundColor White
    }

    # Step 3: Start DocuSpa service
    Write-Host "`nStep 3: Starting DocuSpa service..." -ForegroundColor Cyan
    $StartCommand = "sudo systemctl start docuspa && sleep 5 && sudo systemctl status docuspa --no-pager -l"
    
    $CommandId = aws ssm send-command `
        --instance-ids $InstanceId `
        --document-name "AWS-RunShellScript" `
        --parameters "commands=['$StartCommand']" `
        --region $Region `
        --query 'Command.CommandId' `
        --output text

    if ($CommandId) {
        Write-Host "Start command sent. Waiting for completion..." -ForegroundColor Yellow
        Start-Sleep 15
        
        $Output = aws ssm get-command-invocation `
            --command-id $CommandId `
            --instance-id $InstanceId `
            --region $Region `
            --query 'StandardOutputContent' `
            --output text
            
        Write-Host "Service status:" -ForegroundColor Green
        Write-Host $Output -ForegroundColor White
    }

    # Step 4: Test the API
    Write-Host "`nStep 4: Testing API..." -ForegroundColor Cyan
    $TestCommand = "curl -s http://localhost:8000/auth/test || echo 'API not responding'"
    
    $CommandId = aws ssm send-command `
        --instance-ids $InstanceId `
        --document-name "AWS-RunShellScript" `
        --parameters "commands=['$TestCommand']" `
        --region $Region `
        --query 'Command.CommandId' `
        --output text

    if ($CommandId) {
        Write-Host "Test command sent. Waiting for completion..." -ForegroundColor Yellow
        Start-Sleep 10
        
        $Output = aws ssm get-command-invocation `
            --command-id $CommandId `
            --instance-id $InstanceId `
            --region $Region `
            --query 'StandardOutputContent' `
            --output text
            
        Write-Host "API test result:" -ForegroundColor Green
        Write-Host $Output -ForegroundColor White
    }

    Write-Host "`nFix completed! Test your application at:" -ForegroundColor Green
    Write-Host "http://34.207.84.187/" -ForegroundColor Yellow

} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Ensure your AWS credentials are configured: aws configure" -ForegroundColor White
    Write-Host "2. Ensure the EC2 instance has SSM permissions" -ForegroundColor White
    Write-Host "3. Check that the instance is running and SSM agent is active" -ForegroundColor White
    exit 1
}
