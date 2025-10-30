import os
import requests
from typing import Optional, Dict, Any
from dotenv import load_dotenv

load_dotenv()

class ShareFileAPI:
    def __init__(self):
        self.client_id = os.getenv("SHAREFILE_CLIENT_ID")
        self.client_secret = os.getenv("SHAREFILE_CLIENT_SECRET")
        self.redirect_uri = os.getenv("SHAREFILE_REDIRECT_URI")
        self.base_url = os.getenv("SHAREFILE_BASE_URL", "https://secure.sf-api.com/sf/v3")
        self.access_token = None
        
    def authenticate(self) -> bool:
        """Authenticate using client credentials flow"""
        auth_url = f"{self.base_url}/oauth/token"
        
        data = {
            "grant_type": "client_credentials",
            "client_id": self.client_id,
            "client_secret": self.client_secret
        }
        
        try:
            response = requests.post(auth_url, data=data)
            response.raise_for_status()
            
            token_data = response.json()
            self.access_token = token_data.get("access_token")
            return True
            
        except requests.RequestException as e:
            print(f"Authentication failed: {e}")
            return False
    
    def _make_request(self, method: str, endpoint: str, **kwargs) -> Optional[Dict[Any, Any]]:
        """Make authenticated request to ShareFile API"""
        if not self.access_token:
            if not self.authenticate():
                return None
        
        url = f"{self.base_url}{endpoint}"
        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json"
        }
        
        try:
            response = requests.request(method, url, headers=headers, **kwargs)
            response.raise_for_status()
            return response.json()
        except requests.RequestException as e:
            print(f"API request failed: {e}")
            return None
    
    def get_items(self, folder_id: str = None) -> Optional[Dict[Any, Any]]:
        """Get items from a folder"""
        endpoint = f"/Items({folder_id})/Children" if folder_id else "/Items"
        return self._make_request("GET", endpoint)
    
    def upload_document(self, file_path: str, folder_id: str = None) -> Optional[Dict[Any, Any]]:
        """Upload a document to ShareFile"""
        # This is a simplified implementation
        # Real implementation would need multi-step upload process
        endpoint = f"/Items({folder_id})/Upload" if folder_id else "/Items/Upload"
        return self._make_request("POST", endpoint)
    
    def create_signing_link(self, item_id: str, signer_email: str) -> Optional[str]:
        """Create a signing link for a document"""
        endpoint = f"/Items({item_id})/CreateSigningLink"
        data = {
            "signerEmail": signer_email,
            "redirectUrl": self.redirect_uri
        }
        
        response = self._make_request("POST", endpoint, json=data)
        if response:
            return response.get("url")
        return None
    
    def get_document_status(self, item_id: str) -> Optional[Dict[Any, Any]]:
        """Get document signing status"""
        endpoint = f"/Items({item_id})/SigningStatus"
        return self._make_request("GET", endpoint)