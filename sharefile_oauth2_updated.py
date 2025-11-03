#!/usr/bin/env python3
"""
Updated ShareFile OAuth2 implementation 
This will be updated once we get the proper API documentation
"""

import os
import requests
from typing import Optional, Dict, Any
from dotenv import load_dotenv
from urllib.parse import urlencode
import json

load_dotenv()

class ShareFileOAuth2:
    def __init__(self):
        self.client_id = os.getenv("SHAREFILE_CLIENT_ID")
        self.client_secret = os.getenv("SHAREFILE_CLIENT_SECRET")
        self.redirect_uri = os.getenv("SHAREFILE_REDIRECT_URI")
        
        # These URLs need to be confirmed with ShareFile documentation
        self.auth_base_url = "https://secure.sharefile.com/oauth/authorize"
        self.token_url = "https://secure.sharefile.com/oauth/token"  # Need to verify this
        self.api_base_url = "https://secure.sf-api.com/sf/v3"  # Need to verify this
        
        self.access_token = None
        self.refresh_token = None
        
    def get_authorization_url(self, state: str = None) -> str:
        """
        Generate the authorization URL for OAuth2 Authorization Code flow
        User needs to visit this URL to grant permission
        """
        params = {
            "response_type": "code",
            "client_id": self.client_id,
            "redirect_uri": self.redirect_uri,
            "scope": "full",  # Need to verify correct scopes with documentation
        }
        
        if state:
            params["state"] = state
            
        return f"{self.auth_base_url}?{urlencode(params)}"
    
    def exchange_code_for_token(self, authorization_code: str) -> bool:
        """
        Exchange authorization code for access token
        This happens after user grants permission and we get the code back
        """
        data = {
            "grant_type": "authorization_code",
            "client_id": self.client_id,
            "client_secret": self.client_secret,
            "code": authorization_code,
            "redirect_uri": self.redirect_uri
        }
        
        try:
            response = requests.post(self.token_url, data=data)
            response.raise_for_status()
            
            token_data = response.json()
            self.access_token = token_data.get("access_token")
            self.refresh_token = token_data.get("refresh_token")
            
            return True
            
        except requests.RequestException as e:
            print(f"Token exchange failed: {e}")
            return False
    
    def refresh_access_token(self) -> bool:
        """Refresh the access token using refresh token"""
        if not self.refresh_token:
            return False
            
        data = {
            "grant_type": "refresh_token",
            "client_id": self.client_id,
            "client_secret": self.client_secret,
            "refresh_token": self.refresh_token
        }
        
        try:
            response = requests.post(self.token_url, data=data)
            response.raise_for_status()
            
            token_data = response.json()
            self.access_token = token_data.get("access_token")
            new_refresh_token = token_data.get("refresh_token")
            
            if new_refresh_token:
                self.refresh_token = new_refresh_token
                
            return True
            
        except requests.RequestException as e:
            print(f"Token refresh failed: {e}")
            return False
    
    def make_api_request(self, method: str, endpoint: str, **kwargs) -> Optional[Dict[Any, Any]]:
        """Make authenticated request to ShareFile API"""
        if not self.access_token:
            print("No access token available. Need to complete OAuth2 flow first.")
            return None
        
        url = f"{self.api_base_url}{endpoint}"
        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "Accept": "application/json"
        }
        
        # Add any additional headers from kwargs
        if "headers" in kwargs:
            headers.update(kwargs.pop("headers"))
        
        try:
            response = requests.request(method, url, headers=headers, **kwargs)
            
            # If token expired, try to refresh it
            if response.status_code == 401 and self.refresh_token:
                if self.refresh_access_token():
                    headers["Authorization"] = f"Bearer {self.access_token}"
                    response = requests.request(method, url, headers=headers, **kwargs)
            
            response.raise_for_status()
            return response.json()
            
        except requests.RequestException as e:
            print(f"API request failed: {e}")
            if hasattr(e, 'response') and e.response is not None:
                print(f"Response: {e.response.text}")
            return None

# Example usage functions (to be implemented after getting proper documentation)
class ShareFileAPI(ShareFileOAuth2):
    
    def get_root_folder(self):
        """Get root folder items"""
        return self.make_api_request("GET", "/Items")
    
    def get_folder_items(self, folder_id: str):
        """Get items in a specific folder"""
        return self.make_api_request("GET", f"/Items({folder_id})/Children")
    
    def create_folder(self, name: str, parent_id: str = None):
        """Create a new folder"""
        data = {"Name": name}
        if parent_id:
            data["Parent"] = {"Id": parent_id}
        
        return self.make_api_request("POST", "/Items", json=data)

if __name__ == "__main__":
    # Test the authorization URL generation
    sf_api = ShareFileAPI()
    auth_url = sf_api.get_authorization_url("test_state")
    print("ShareFile Authorization URL:")
    print(auth_url)
    print("\nNOTE: This URL needs to be verified with ShareFile API documentation")