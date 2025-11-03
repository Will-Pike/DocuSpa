#!/usr/bin/env python3
"""
Debug ShareFile API responses to understand the folder/file structure
Run this on your EC2 instance to see what ShareFile is actually returning
"""

import sys
sys.path.append('.')
from app.database import SessionLocal
from app.models.user import User, UserRole
from app.models.sharefile import ShareFileCredentials
from app.services.sharefile import ShareFileAPI
import json

def debug_sharefile_structure():
    """Debug the ShareFile API responses"""
    db = SessionLocal()
    
    try:
        # Get organization-wide ShareFile credentials
        credentials = db.query(ShareFileCredentials).filter(
            ShareFileCredentials.organization_wide == True,
            ShareFileCredentials.is_active == True
        ).first()
        
        if not credentials:
            print("❌ No ShareFile credentials found")
            return
        
        print("🔍 ShareFile Debug Information")
        print("=" * 50)
        print(f"Subdomain: {credentials.subdomain}")
        print(f"APICP: {credentials.apicp}")
        print(f"Has Access Token: {bool(credentials.access_token)}")
        print(f"Has Refresh Token: {bool(credentials.refresh_token)}")
        
        # Initialize ShareFile API
        sf_api = ShareFileAPI()
        sf_api.access_token = credentials.access_token
        sf_api.refresh_token = credentials.refresh_token
        sf_api.subdomain = credentials.subdomain
        sf_api.apicp = credentials.apicp
        sf_api.appcp = credentials.appcp
        
        print("\n🧪 Testing API Connection...")
        
        # Test 1: Get home folder
        print("\n1️⃣ Getting home folder...")
        home_response = sf_api.get_home_folder()
        if home_response:
            print("✅ Home folder response received")
            print(f"   Home folder ID: {home_response.get('Id')}")
            print(f"   Home folder Name: {home_response.get('Name')}")
            print(f"   Home folder Type: {home_response.get('Type')}")
            
            # Test 2: Get children of home folder
            print("\n2️⃣ Getting home folder children...")
            if home_response.get('Id'):
                children_response = sf_api.get_items(home_response['Id'])
                if children_response:
                    print("✅ Children response received")
                    
                    # Check if response has 'value' array
                    items = children_response.get('value', [])
                    if not items and isinstance(children_response, list):
                        items = children_response
                    
                    print(f"   Found {len(items)} items in home folder")
                    
                    for i, item in enumerate(items):
                        item_type = item.get('Type', 'Unknown')
                        item_name = item.get('Name', 'Unknown')
                        item_id = item.get('Id', 'Unknown')
                        item_size = item.get('FileSizeBytes', 0)
                        
                        print(f"\n   📋 Item {i+1}:")
                        print(f"      ID: {item_id}")
                        print(f"      Name: {item_name}")
                        print(f"      Type: {item_type}")
                        print(f"      Size: {item_size} bytes")
                        
                        # If it's a folder, let's see what's inside
                        if item_type == 'Folder':
                            print(f"\n      🔍 Looking inside folder '{item_name}'...")
                            folder_contents = sf_api.get_items(item_id)
                            if folder_contents:
                                folder_items = folder_contents.get('value', [])
                                if not folder_items and isinstance(folder_contents, list):
                                    folder_items = folder_contents
                                
                                print(f"         Found {len(folder_items)} items in folder")
                                for j, folder_item in enumerate(folder_items):
                                    f_type = folder_item.get('Type', 'Unknown')
                                    f_name = folder_item.get('Name', 'Unknown')
                                    f_size = folder_item.get('FileSizeBytes', 0)
                                    print(f"         📄 Item {j+1}: {f_name} ({f_type}) - {f_size} bytes")
                            else:
                                print("         ❌ Could not get folder contents")
                else:
                    print("❌ Could not get home folder children")
            else:
                print("❌ Home folder has no ID")
        else:
            print("❌ Could not get home folder")
        
        # Test 3: Try direct /Items call
        print("\n3️⃣ Testing direct /Items call...")
        direct_response = sf_api._make_request("GET", "/Items")
        if direct_response:
            print("✅ Direct /Items response received")
            if isinstance(direct_response, dict):
                items = direct_response.get('value', [])
                print(f"   Found {len(items)} items via direct call")
            else:
                print(f"   Response type: {type(direct_response)}")
        else:
            print("❌ Direct /Items call failed")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        db.close()

if __name__ == "__main__":
    debug_sharefile_structure()