#!/usr/bin/env python3

import requests
import json

def get_working_sharefile_access():
    """Get working ShareFile access bypassing auth issues"""
    
    print("🔧 Getting debug token...")
    
    # Get debug token
    token_response = requests.get("http://localhost:8000/debug/token")
    
    if token_response.status_code == 200:
        token_data = token_response.json()
        token = token_data['access_token']
        print(f"✅ Debug token obtained: {token[:50]}...")
        
        # Test ShareFile status
        print("\n📊 Testing ShareFile status...")
        headers = {'Authorization': f'Bearer {token}'}
        
        status_response = requests.get("http://localhost:8000/admin/sharefile/status", headers=headers)
        print(f"Status Code: {status_response.status_code}")
        
        if status_response.status_code == 200:
            status_data = status_response.json()
            print(f"ShareFile Status: {json.dumps(status_data, indent=2)}")
        else:
            print(f"Status Error: {status_response.text}")
        
        # Test ShareFile files (this should show your folders/files)
        print("\n📁 Testing ShareFile files...")
        files_response = requests.get("http://localhost:8000/admin/sharefile/files", headers=headers)
        print(f"Files Code: {files_response.status_code}")
        
        if files_response.status_code == 200:
            files_data = files_response.json()
            print(f"ShareFile Files Response:")
            print(json.dumps(files_data, indent=2))
            
            # If we have files, let's try downloading one
            if files_data.get('files') and len(files_data['files']) > 0:
                file_id = files_data['files'][0].get('id')
                file_name = files_data['files'][0].get('name')
                
                print(f"\n⬇️ Testing download for: {file_name} (ID: {file_id})")
                download_response = requests.get(f"http://localhost:8000/admin/sharefile/file/{file_id}/download-url", headers=headers)
                print(f"Download Status: {download_response.status_code}")
                print(f"Download Response: {download_response.text}")
        else:
            print(f"Files Error: {files_response.text}")
        
        print(f"\n🎯 To use in browser:")
        print(f"1. Open http://localhost:8000/dashboard")
        print(f"2. Open DevTools (F12)")
        print(f"3. Run: localStorage.setItem('access_token', '{token}')")
        print(f"4. Refresh page")
        
    else:
        print(f"❌ Debug token failed: {token_response.text}")

if __name__ == "__main__":
    get_working_sharefile_access()