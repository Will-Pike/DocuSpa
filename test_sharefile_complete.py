#!/usr/bin/env python3
"""
Test ShareFile connection after OAuth2 setup
"""

import requests

def test_sharefile_setup():
    """Test if ShareFile OAuth2 setup was successful"""
    
    # First login to get admin token
    login_data = {
        "email": "wilpike@gmail.com",
        "password": "admin123!"
    }
    
    try:
        # Get admin token
        login_response = requests.post("http://localhost:8000/auth/login", json=login_data)
        if login_response.status_code != 200:
            print("❌ Failed to login as admin")
            return
        
        token = login_response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        print("✅ Admin login successful")
        
        # Test ShareFile connection
        sf_response = requests.get("http://localhost:8000/admin/sharefile/test", headers=headers)
        
        if sf_response.status_code == 200:
            result = sf_response.json()
            print(f"📊 ShareFile Status: {result.get('status')}")
            print(f"📝 Message: {result.get('message')}")
            
            if result.get('status') == 'oauth2_required':
                print("\n🔧 Completing OAuth2 setup...")
                
                # Complete OAuth2 setup with your parameters
                callback_params = {
                    "code": "fksEU8lRrISFxbQZIOgqmT1Dui9Sqf",
                    "subdomain": "deepblue",
                    "apicp": "sf-api.com",
                    "appcp": "sharefile.com",
                    "state": "admin_setup"
                }
                
                callback_response = requests.post(
                    "http://localhost:8000/admin/sharefile/callback",
                    params=callback_params,
                    headers=headers
                )
                
                if callback_response.status_code == 200:
                    callback_result = callback_response.json()
                    print(f"🎉 {callback_result.get('message')}")
                    print(f"📂 Subdomain: {callback_result.get('subdomain')}")
                    print(f"🌐 API Control Plane: {callback_result.get('apicp')}")
                    
                    if callback_result.get('home_folder'):
                        print("✅ ShareFile API access confirmed!")
                    else:
                        print("⚠️  OAuth2 setup complete but API access needs verification")
                else:
                    print(f"❌ OAuth2 callback failed: {callback_response.text}")
            else:
                print("✅ ShareFile connection already configured!")
        else:
            print(f"❌ ShareFile test failed: {sf_response.text}")
            
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    print("🔍 Testing ShareFile OAuth2 Setup...")
    print("=" * 50)
    test_sharefile_setup()