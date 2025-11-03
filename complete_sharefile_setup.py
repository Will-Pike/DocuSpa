#!/usr/bin/env python3
"""
Complete ShareFile OAuth2 setup directly
"""

from app.services.sharefile import ShareFileAPI
from dotenv import load_dotenv

load_dotenv()

def complete_oauth2_setup():
    """Complete ShareFile OAuth2 setup with your authorization code"""
    
    # Your OAuth2 parameters from the callback
    code = "fksEU8lRrISFxbQZIOgqmT1Dui9Sqf"
    subdomain = "deepblue"
    apicp = "sf-api.com"
    appcp = "sharefile.com"
    
    print("🔧 Completing ShareFile OAuth2 setup...")
    print(f"📊 Subdomain: {subdomain}")
    print(f"🌐 API Control Plane: {apicp}")
    print(f"🏢 App Control Plane: {appcp}")
    print()
    
    # Initialize ShareFile API
    sf_api = ShareFileAPI()
    
    # Exchange authorization code for tokens
    print("🔄 Exchanging authorization code for access tokens...")
    success = sf_api.exchange_code_for_token(code, subdomain, apicp, appcp)
    
    if success:
        print("✅ Token exchange successful!")
        print(f"🔑 Access token obtained: {sf_api.access_token[:20]}...")
        
        # Test the API connection
        print("\n📂 Testing ShareFile API access...")
        home_folder = sf_api.get_home_folder()
        
        if home_folder:
            print("✅ ShareFile API connection successful!")
            print(f"📁 Home folder ID: {home_folder.get('Id', 'Unknown')}")
            print(f"📝 Folder name: {home_folder.get('Name', 'Unknown')}")
            
            # Test getting folder items
            print("\n📋 Testing folder items access...")
            items = sf_api.get_items()
            if items and 'value' in items:
                print(f"📊 Found {len(items['value'])} items in home folder")
                for item in items['value'][:3]:  # Show first 3 items
                    print(f"  - {item.get('Name', 'Unknown')} ({item.get('Type', 'Unknown')})")
            else:
                print("📂 Home folder is empty or access limited")
                
            print(f"\n🎉 ShareFile integration is now fully configured!")
            print(f"🔗 API Base URL: https://{subdomain}.{apicp}/sf/v3")
            
            return True
        else:
            print("❌ Failed to access ShareFile API")
            return False
    else:
        print("❌ Failed to exchange authorization code for tokens")
        return False

if __name__ == "__main__":
    print("ShareFile OAuth2 Setup Completion")
    print("=" * 50)
    complete_oauth2_setup()