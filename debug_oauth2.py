#!/usr/bin/env python3
"""
Debug ShareFile OAuth2 token exchange
"""

import requests
from dotenv import load_dotenv
import os

load_dotenv()

def debug_token_exchange():
    """Debug the ShareFile token exchange process"""
    
    # Your OAuth2 parameters
    code = "fksEU8lRrISFxbQZIOgqmT1Dui9Sqf"
    subdomain = "deepblue"
    apicp = "sf-api.com"
    appcp = "sharefile.com"
    
    client_id = os.getenv("SHAREFILE_CLIENT_ID")
    client_secret = os.getenv("SHAREFILE_CLIENT_SECRET")
    
    print("🔍 Debugging ShareFile OAuth2 Token Exchange")
    print("=" * 60)
    print(f"🔑 Client ID: {client_id}")
    print(f"📊 Subdomain: {subdomain}")
    print(f"🌐 API Control Plane: {apicp}")
    print(f"🔗 Token URL: https://{subdomain}.{apicp}/oauth/token")
    print()
    
    # Prepare token exchange request
    token_url = f"https://{subdomain}.{apicp}/oauth/token"
    
    data = {
        "grant_type": "authorization_code",
        "code": code,
        "client_id": client_id,
        "client_secret": client_secret
    }
    
    headers = {
        "Content-Type": "application/x-www-form-urlencoded"
    }
    
    print("📤 Request Details:")
    print(f"URL: {token_url}")
    print(f"Headers: {headers}")
    print(f"Data: {data}")
    print()
    
    try:
        print("🚀 Making token exchange request...")
        response = requests.post(token_url, data=data, headers=headers)
        
        print(f"📨 Response Status: {response.status_code}")
        print(f"📋 Response Headers: {dict(response.headers)}")
        print(f"📄 Response Body: {response.text}")
        
        if response.status_code != 200:
            print(f"\n❌ Token exchange failed with status {response.status_code}")
            
            # Try different variations of the URL
            print("\n🔄 Trying alternative URLs...")
            
            # Try with sharefile.com instead of sf-api.com
            alt_url1 = f"https://{subdomain}.sharefile.com/oauth/token"
            print(f"🔗 Trying: {alt_url1}")
            
            alt_response1 = requests.post(alt_url1, data=data, headers=headers)
            print(f"📨 Status: {alt_response1.status_code}, Response: {alt_response1.text}")
            
            # Try the secure.sharefile.com URL
            alt_url2 = "https://secure.sharefile.com/oauth/token"
            print(f"🔗 Trying: {alt_url2}")
            
            alt_response2 = requests.post(alt_url2, data=data, headers=headers)
            print(f"📨 Status: {alt_response2.status_code}, Response: {alt_response2.text}")
            
        else:
            print("✅ Token exchange successful!")
            
    except Exception as e:
        print(f"❌ Request failed: {e}")

if __name__ == "__main__":
    debug_token_exchange()