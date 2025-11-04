#!/usr/bin/env python3

import requests
import json
import os
from dotenv import load_dotenv

def test_local_sharefile():
    """Debug ShareFile authentication on local machine"""
    
    load_dotenv()  # Load environment variables
    
    print("🔍 ShareFile Local Debug")
    print("=" * 40)
    
    # Check environment variables
    client_id = os.getenv("SHAREFILE_CLIENT_ID")
    client_secret = os.getenv("SHAREFILE_CLIENT_SECRET") 
    redirect_uri = os.getenv("SHAREFILE_REDIRECT_URI")
    
    print(f"🔑 Client ID: {client_id[:10] + '...' if client_id else 'NOT SET'}")
    print(f"🔒 Client Secret: {'SET' if client_secret else 'NOT SET'}")
    print(f"🔄 Redirect URI: {redirect_uri}")
    print()
    
    # Test login
    login_data = {
        "email": "admin@docuspa.com", 
        "password": "admin123"
    }
    
    try:
        login_response = requests.post("http://localhost:8000/auth/login", json=login_data)
        
        if login_response.status_code == 200:
            login_result = login_response.json()
            token = login_result.get('access_token')
            print(f"✅ Login successful, token: {token[:20]}...")
            
            # Test ShareFile status
            headers = {
                'Authorization': f'Bearer {token}',
                'Content-Type': 'application/json'
            }
            
            # Test ShareFile status endpoint
            print("\n📊 Testing ShareFile Status...")
            status_response = requests.get("http://localhost:8000/admin/sharefile/status", headers=headers)
            print(f"Status Code: {status_response.status_code}")
            
            if status_response.status_code == 200:
                status_data = status_response.json()
                print(f"ShareFile Status: {json.dumps(status_data, indent=2)}")
            else:
                print(f"Status Error: {status_response.text}")
            
            # Test auth URL generation
            print("\n🔗 Testing Auth URL Generation...")
            auth_response = requests.get("http://localhost:8000/admin/sharefile/auth-url", headers=headers)
            print(f"Auth URL Code: {auth_response.status_code}")
            
            if auth_response.status_code == 200:
                auth_data = auth_response.json()
                print(f"Auth URL: {auth_data.get('authorization_url', 'NOT FOUND')}")
            else:
                print(f"Auth URL Error: {auth_response.text}")
                
            # Test ShareFile files endpoint 
            print("\n📁 Testing ShareFile Files...")
            files_response = requests.get("http://localhost:8000/admin/sharefile/files", headers=headers)
            print(f"Files Code: {files_response.status_code}")
            
            if files_response.status_code == 200:
                files_data = files_response.json()
                print(f"Files Response: {json.dumps(files_data, indent=2)}")
                
                # If we have files, try to download one
                if files_data.get('files'):
                    file_id = files_data['files'][0].get('id')
                    if file_id:
                        print(f"\n⬇️ Testing Download for file: {file_id}")
                        download_response = requests.get(f"http://localhost:8000/admin/sharefile/file/{file_id}/download-url", headers=headers)
                        print(f"Download Code: {download_response.status_code}")
                        print(f"Download Response: {download_response.text}")
            else:
                print(f"Files Error: {files_response.text}")
            
        else:
            print(f"❌ Login failed: {login_response.text}")
            
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    test_local_sharefile()