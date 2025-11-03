#!/usr/bin/env python3
"""
Test admin registration using requests
"""

import requests
import json

def test_admin_registration():
    url = "http://localhost:8000/auth/register-admin"
    data = {
        "email": "wilpike@gmail.com",
        "password": "admin2025!@"
    }
    
    try:
        # First test if server is responding
        response = requests.get("http://localhost:8000/")
        print(f"Server health check: {response.status_code}")
        
        # Now try admin registration
        response = requests.post(url, json=data, timeout=10)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
        
        if response.status_code == 200:
            print("✅ Admin user created successfully!")
        else:
            print(f"❌ Error: {response.status_code}")
            
    except requests.exceptions.ConnectionError:
        print("❌ Cannot connect to server. Is it running on port 8000?")
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    test_admin_registration()