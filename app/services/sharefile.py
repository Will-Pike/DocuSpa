import os
import requests
import hmac
import hashlib
import base64
from datetime import datetime
from typing import Optional, Dict, Any
from urllib.parse import urlencode, urlparse, parse_qs
from dotenv import load_dotenv

load_dotenv()

class ShareFileAPI:
    def __init__(self):
        self.client_id = os.getenv("SHAREFILE_CLIENT_ID")
        self.client_secret = os.getenv("SHAREFILE_CLIENT_SECRET")
        self.redirect_uri = os.getenv("SHAREFILE_REDIRECT_URI")
        
        # These will be set after OAuth2 flow
        self.access_token = None
        self.refresh_token = None
        self.subdomain = None
        self.apicp = None
        self.appcp = None
    def get_authorization_url(self, state: str = None) -> str:
        """
        Generate ShareFile authorization URL for OAuth2 flow
        User must visit this URL to grant permission
        """
        params = {
            "response_type": "code",
            "client_id": self.client_id,
            "redirect_uri": self.redirect_uri,
        }
        
        if state:
            params["state"] = state
            
        auth_url = "https://secure.sharefile.com/oauth/authorize"
        return f"{auth_url}?{urlencode(params)}"
    
    def validate_redirect_hash(self, request_uri: str) -> bool:
        """
        Validate HMAC signature from ShareFile redirect to prevent tampering
        """
        try:
            parsed = urlparse(request_uri)
            query_params = parse_qs(parsed.query)
            
            # Get the hash parameter
            if 'h' not in query_params:
                return False
            
            received_hash = query_params['h'][0]
            
            # Remove hash parameter and reconstruct query string
            filtered_params = {k: v for k, v in query_params.items() if k != 'h'}
            query_string = urlencode(filtered_params, doseq=True)
            path_and_query = f"{parsed.path}?{query_string}"
            
            # Calculate expected hash
            message = path_and_query.encode('utf-8')
            secret = self.client_secret.encode('utf-8')
            expected_hash = hmac.new(secret, message, hashlib.sha256).digest()
            expected_hash_b64 = base64.b64encode(expected_hash).decode('utf-8')
            expected_hash_urlencoded = urlencode({'h': expected_hash_b64})[2:]  # Remove 'h='
            
            return received_hash == expected_hash_urlencoded
            
        except Exception as e:
            print(f"Hash validation error: {e}")
            return False
    
    def exchange_code_for_token(self, code: str, subdomain: str, apicp: str, appcp: str = None) -> bool:
        """
        Exchange authorization code for access and refresh tokens
        """
        self.subdomain = subdomain
        self.apicp = apicp
        self.appcp = appcp or apicp
        
        token_url = f"https://{subdomain}.{apicp}/oauth/token"
        
        data = {
            "grant_type": "authorization_code",
            "code": code,
            "client_id": self.client_id,
            "client_secret": self.client_secret
        }
        
        headers = {
            "Content-Type": "application/x-www-form-urlencoded"
        }
        
        try:
            response = requests.post(token_url, data=data, headers=headers)
            response.raise_for_status()
            
            token_data = response.json()
            self.access_token = token_data.get("access_token")
            self.refresh_token = token_data.get("refresh_token")
            
            # Update control plane info if returned
            self.subdomain = token_data.get("subdomain", subdomain)
            self.apicp = token_data.get("apicp", apicp)
            self.appcp = token_data.get("appcp", appcp)
            
            return True
            
        except requests.RequestException as e:
            print(f"Token exchange failed: {e}")
            if hasattr(e, 'response') and e.response:
                print(f"Response: {e.response.text}")
            return False
    
    def refresh_access_token(self, db_session=None, user_id=None) -> bool:
        """
        Refresh expired access token using refresh token
        If db_session and user_id provided, also update stored credentials
        """
        if not self.refresh_token or not self.subdomain or not self.apicp:
            print("Missing refresh token or connection details")
            return False
            
        token_url = f"https://{self.subdomain}.{self.apicp}/oauth/token"
        
        data = {
            "grant_type": "refresh_token",
            "refresh_token": self.refresh_token,
            "client_id": self.client_id,
            "client_secret": self.client_secret
        }
        
        headers = {
            "Content-Type": "application/x-www-form-urlencoded"
        }
        
        try:
            print(f"Refreshing token for {self.subdomain}.{self.apicp}")
            response = requests.post(token_url, data=data, headers=headers)
            response.raise_for_status()
            
            token_data = response.json()
            old_access_token = self.access_token
            self.access_token = token_data.get("access_token")
            
            # Update refresh token if new one provided
            new_refresh_token = token_data.get("refresh_token")
            if new_refresh_token:
                self.refresh_token = new_refresh_token
            
            # Update stored credentials if database session provided
            if db_session and user_id:
                try:
                    from app.models.sharefile import ShareFileCredentials
                    credentials = db_session.query(ShareFileCredentials).filter(
                        ShareFileCredentials.user_id == user_id
                    ).first()
                    
                    if credentials:
                        credentials.access_token = self.access_token
                        if new_refresh_token:
                            credentials.refresh_token = self.refresh_token
                        credentials.last_refreshed = datetime.utcnow()
                        db_session.commit()
                        print("Updated stored credentials after token refresh")
                except Exception as e:
                    print(f"Failed to update stored credentials: {e}")
                
            print(f"Token refreshed successfully: {old_access_token[:20]}... -> {self.access_token[:20]}...")
            return True
            
        except requests.RequestException as e:
            print(f"Token refresh failed: {e}")
            if hasattr(e, 'response') and e.response:
                print(f"Response: {e.response.text}")
            return False
    
    def is_token_expired(self) -> bool:
        """
        Check if access token needs refreshing
        ShareFile tokens typically expire after 8 hours
        """
        # For now, we'll rely on API response to determine expiration
        # In production, you might want to track token creation time
        return False
    
    def ensure_valid_token(self, db_session=None, user_id=None) -> bool:
        """
        Ensure we have a valid access token, refresh if needed
        """
        if not self.access_token:
            return False
            
        # Try a simple API call to test token validity using the home folder endpoint
        try:
            test_response = self._make_request("GET", "/Items(home)", 
                                              skip_refresh=True, 
                                              db_session=db_session, 
                                              user_id=user_id)
            return test_response is not None
        except:
            # If test fails, try refreshing the token
            if self.refresh_token:
                print("Token validation failed, attempting refresh...")
                refresh_success = self.refresh_access_token(db_session, user_id)
                if refresh_success:
                    # Test again with the new token
                    try:
                        test_response = self._make_request("GET", "/Items(home)", 
                                                          skip_refresh=True, 
                                                          db_session=db_session, 
                                                          user_id=user_id)
                        return test_response is not None
                    except:
                        print("Token validation still failed after refresh")
                        return False
                return False
            return False
    
    def _make_request(self, method: str, endpoint: str, skip_refresh: bool = False, 
                     db_session=None, user_id=None, **kwargs) -> Optional[Dict[Any, Any]]:
        """
        Make authenticated request to ShareFile API with automatic token refresh
        """
        if not self.access_token or not self.subdomain or not self.apicp:
            print("Not authenticated - missing access token or connection details")
            return None
        
        # Use dynamic URL based on user's ShareFile instance
        base_url = f"https://{self.subdomain}.{self.apicp}/sf/v3"
        url = f"{base_url}{endpoint}"
        
        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "Accept": "application/json"
        }
        
        # Add any additional headers from kwargs
        if "headers" in kwargs:
            headers.update(kwargs.pop("headers"))
        
        try:
            response = requests.request(method, url, headers=headers, **kwargs)
            
            # Try to refresh token if we get 401 Unauthorized (unless skip_refresh is True)
            if response.status_code == 401 and self.refresh_token and not skip_refresh:
                print("Access token expired, attempting refresh...")
                if self.refresh_access_token(db_session, user_id):
                    print("Token refreshed successfully, retrying request...")
                    headers["Authorization"] = f"Bearer {self.access_token}"
                    response = requests.request(method, url, headers=headers, **kwargs)
                else:
                    print("Token refresh failed")
            
            response.raise_for_status()
            
            # Try to parse JSON, but handle non-JSON responses
            try:
                return response.json()
            except ValueError:
                return {"status": "success", "content": response.text}
            
        except requests.RequestException as e:
            print(f"API request failed: {e}")
            if hasattr(e, 'response') and e.response:
                print(f"Response status: {e.response.status_code}")
                print(f"Response: {e.response.text}")
            return None
    
    def get_items(self, folder_id: str = None) -> Optional[Dict[Any, Any]]:
        """Get items from a folder"""
        if folder_id:
            endpoint = f"/Items({folder_id})/Children"
        else:
            endpoint = "/Items(home)"  # Get home folder items
        return self._make_request("GET", endpoint)
    
    def get_home_folder(self) -> Optional[Dict[Any, Any]]:
        """Get user's home folder"""
        return self._make_request("GET", "/Items(home)")
    
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