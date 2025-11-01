# DocuSpa Deployment Fix - PowerShell Script
# This script helps fix the authentication issues on the deployed EC2 instance

param(
    [Parameter(Mandatory=$true)]
    [string]$KeyPath,
    
    [Parameter(Mandatory=$true)]
    [string]$ServerIP = "34.207.84.187"
)

Write-Host "🔧 DocuSpa Authentication Fix Script" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green

# Verify key file exists
if (-not (Test-Path $KeyPath)) {
    Write-Host "❌ Key file not found: $KeyPath" -ForegroundColor Red
    exit 1
}

Write-Host "📁 Using key file: $KeyPath" -ForegroundColor Yellow
Write-Host "🌐 Connecting to: $ServerIP" -ForegroundColor Yellow

try {
    # Copy the fix script to the server
    Write-Host "`n📤 Uploading fix script..." -ForegroundColor Cyan
    scp -i $KeyPath "c:\Code\DocuSpa\deploy\fix_auth_deployment.sh" "ec2-user@${ServerIP}:/tmp/"
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to upload fix script"
    }
    
    # Make the script executable and run it
    Write-Host "🚀 Running authentication fix..." -ForegroundColor Cyan
    ssh -i $KeyPath "ec2-user@$ServerIP" @"
chmod +x /tmp/fix_auth_deployment.sh
sudo /tmp/fix_auth_deployment.sh
"@
      if ($LASTEXITCODE -ne 0) {
        throw "Fix script execution failed"
    }
    
    # Upload and run verification script
    Write-Host "`n📤 Uploading verification script..." -ForegroundColor Cyan
    scp -i $KeyPath "c:\Code\DocuSpa\deploy\verify_deployment.sh" "ec2-user@${ServerIP}:/tmp/"
    
    Write-Host "🔍 Running deployment verification..." -ForegroundColor Cyan
    ssh -i $KeyPath "ec2-user@$ServerIP" @"
chmod +x /tmp/verify_deployment.sh
sudo /tmp/verify_deployment.sh
"@
      Write-Host "`nFix completed successfully!" -ForegroundColor Green
    Write-Host "Test the application at: http://$ServerIP" -ForegroundColor Yellow
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "`nManual steps to try:" -ForegroundColor Yellow
    Write-Host "1. Connect via SSH: ssh -i $KeyPath ec2-user@$ServerIP" -ForegroundColor White
    Write-Host "2. Check service status: sudo systemctl status docuspa" -ForegroundColor White
    Write-Host "3. View logs: sudo journalctl -u docuspa -f" -ForegroundColor White
    exit 1
}
