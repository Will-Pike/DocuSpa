#!/usr/bin/env python3

import requests
import json

def test_sharefile_auth_url():
    """Test the ShareFile auth URL endpoint"""
    
    # First, get an admin token
    login_data = {
        "username": "admin",
        "password": "admin123"
    }
    
    login_response = requests.post("http://54.234.42.228:8000/login", json=login_data)
    
    if login_response.status_code == 200:
        login_result = login_response.json()
        token = login_result.get('access_token')
        print(f"✅ Login successful, token: {token[:20]}...")
        
        # Now test the auth URL endpoint
        headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json'
        }
        
        auth_response = requests.get("http://54.234.42.228:8000/admin/sharefile/auth-url", headers=headers)
        
        print(f"🔍 Auth URL Status: {auth_response.status_code}")
        print(f"📄 Response: {auth_response.text}")
        
        if auth_response.status_code == 200:
            auth_data = auth_response.json()
            print(f"🎉 Authorization URL: {auth_data.get('authorization_url')}")
        else:
            print(f"❌ Auth URL failed: {auth_response.text}")
            
    else:
        print(f"❌ Login failed: {login_response.text}")

if __name__ == "__main__":
    test_sharefile_auth_url()