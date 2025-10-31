#!/usr/bin/env python3
"""
Test ShareFile OAuth2 authentication in detail
"""

import os
import requests
from dotenv import load_dotenv

load_dotenv()

def test_sharefile_auth():
    """Test different ShareFile authentication methods"""
    
    client_id = os.getenv("SHAREFILE_CLIENT_ID")
    client_secret = os.getenv("SHAREFILE_CLIENT_SECRET") 
    base_url = os.getenv("SHAREFILE_BASE_URL", "https://secure.sf-api.com/sf/v3")
    
    print("🔐 ShareFile OAuth2 Authentication Test")
    print("=" * 50)
    print(f"Client ID: {client_id}")
    print(f"Base URL: {base_url}")
    print()
    
    # Test 1: Client Credentials Flow
    print("📋 Testing Client Credentials Flow...")
    auth_url = f"{base_url}/oauth/token"
    
    data = {
        "grant_type": "client_credentials",
        "client_id": client_id,
        "client_secret": client_secret
    }
    
    try:
        response = requests.post(auth_url, data=data)
        print(f"Status Code: {response.status_code}")
        print(f"Response Headers: {dict(response.headers)}")
        print(f"Response Body: {response.text}")
        
        if response.status_code == 200:
            token_data = response.json()
            access_token = token_data.get("access_token")
            print(f"✅ Got access token: {access_token[:20]}...")
            
            # Test the token with a simple API call
            print("\n📊 Testing API call with token...")
            api_url = f"{base_url}/Items"
            headers = {
                "Authorization": f"Bearer {access_token}",
                "Accept": "application/json"
            }
            
            api_response = requests.get(api_url, headers=headers)
            print(f"API Status Code: {api_response.status_code}")
            print(f"API Response: {api_response.text}")
            
        else:
            print(f"❌ Authentication failed")
            
    except Exception as e:
        print(f"❌ Error: {e}")
    
    # Test 2: Check if we need Authorization Code flow instead
    print("\n🔄 ShareFile may require Authorization Code flow...")
    print("This typically involves:")
    print("1. Redirect user to ShareFile authorization URL")
    print("2. User grants permission")
    print("3. ShareFile redirects back with authorization code")
    print("4. Exchange code for access token")
    
    auth_code_url = f"https://secure.sharefile.com/oauth/authorize"
    print(f"Authorization URL would be: {auth_code_url}")
    print(f"Redirect URI: {os.getenv('SHAREFILE_REDIRECT_URI')}")

if __name__ == "__main__":
    test_sharefile_auth()