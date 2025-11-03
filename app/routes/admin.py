from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List
from datetime import datetime, timedelta

from app.database import get_db
from app.models.user import User
from app.models.spa import Spa, SpaStatus
from app.routes.auth import get_current_user
from app.services.sharefile import ShareFileAPI

router = APIRouter()

class SpaResponse(BaseModel):
    id: str
    name: str
    contact_email: str
    status: str
    created_at: str
    
    class Config:
        from_attributes = True

class CreateSpaRequest(BaseModel):
    name: str
    contact_email: str

class DashboardStats(BaseModel):
    total_spas: int
    invited: int
    info_submitted: int
    documents_signed: int
    payment_setup: int
    completed: int

@router.get("/dashboard-stats", response_model=DashboardStats)
async def get_dashboard_stats(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get dashboard statistics for admin"""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    total_spas = db.query(Spa).count()
    invited = db.query(Spa).filter(Spa.status == SpaStatus.invited).count()
    info_submitted = db.query(Spa).filter(Spa.status == SpaStatus.info_submitted).count()
    documents_signed = db.query(Spa).filter(Spa.status == SpaStatus.documents_signed).count()
    payment_setup = db.query(Spa).filter(Spa.status == SpaStatus.payment_setup).count()
    completed = db.query(Spa).filter(Spa.status == SpaStatus.completed).count()
    
    return DashboardStats(
        total_spas=total_spas,
        invited=invited,
        info_submitted=info_submitted,
        documents_signed=documents_signed,
        payment_setup=payment_setup,
        completed=completed
    )

@router.get("/spas", response_model=List[SpaResponse])
async def get_all_spas(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all spas for admin dashboard"""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    spas = db.query(Spa).all()
    return [
        SpaResponse(
            id=spa.id,
            name=spa.name,
            contact_email=spa.contact_email,
            status=spa.status.value,
            created_at=spa.created_at.isoformat()
        )
        for spa in spas
    ]

@router.post("/spas", response_model=SpaResponse)
async def create_spa(
    spa_data: CreateSpaRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a new spa and start onboarding workflow"""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    new_spa = Spa(
        name=spa_data.name,
        contact_email=spa_data.contact_email,
        status=SpaStatus.invited
    )
    
    db.add(new_spa)
    db.commit()
    db.refresh(new_spa)
    
    # TODO: Send invitation email to spa
    
    return SpaResponse(
        id=new_spa.id,
        name=new_spa.name,
        contact_email=new_spa.contact_email,
        status=new_spa.status.value,
        created_at=new_spa.created_at.isoformat()
    )

@router.get("/spas/{spa_id}", response_model=SpaResponse)
async def get_spa_details(
    spa_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get detailed spa information"""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    spa = db.query(Spa).filter(Spa.id == spa_id).first()
    if not spa:
        raise HTTPException(status_code=404, detail="Spa not found")
    
    return SpaResponse(
        id=spa.id,
        name=spa.name,
        contact_email=spa.contact_email,
        status=spa.status.value,
        created_at=spa.created_at.isoformat()
    )

@router.get("/sharefile/auth-url")
async def get_sharefile_auth_url(current_user: User = Depends(get_current_user)):
    """Get ShareFile OAuth2 authorization URL with enhanced user experience"""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    sf_api = ShareFileAPI()
    auth_url = sf_api.get_authorization_url(state="admin_setup")
    
    return {
        "authorization_url": auth_url,
        "instructions": [
            "1. Click the authorization URL below to open ShareFile",
            "2. Log in to your ShareFile account if not already logged in",
            "3. Click 'Allow' to authorize DocuSpa to access your files",
            "4. You'll be redirected back to complete the setup automatically"
        ],
        "user_friendly_steps": {
            "step1": "The link will open ShareFile in a new tab",
            "step2": "ShareFile will ask you to authorize DocuSpa",
            "step3": "After clicking Allow, you'll be redirected back",
            "step4": "The setup will complete automatically"
        },
        "troubleshooting": {
            "if_stuck": "If the page doesn't redirect automatically, copy the URL from the address bar and paste it in the callback form",
            "token_expires": "The authorization link expires in 10-15 minutes, so complete setup promptly"
        }
    }

@router.get("/sharefile/status")
async def get_sharefile_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get current ShareFile connection status and token health"""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    from app.models.sharefile import ShareFileCredentials
    
    # Get organization-wide ShareFile credentials (shared by all admins)
    credentials = db.query(ShareFileCredentials).filter(
        ShareFileCredentials.organization_wide == True,
        ShareFileCredentials.is_active == True
    ).first()
    
    if not credentials:
        return {
            "status": "not_connected",
            "message": "No organization-wide ShareFile connection found",
            "setup_required": True
        }
    
    # Test token validity
    sf_api = ShareFileAPI()
    sf_api.access_token = credentials.access_token
    sf_api.refresh_token = credentials.refresh_token
    sf_api.subdomain = credentials.subdomain
    sf_api.apicp = credentials.apicp
    sf_api.appcp = credentials.appcp
    
    # Check if token is valid
    is_valid = sf_api.ensure_valid_token(db, current_user.id)
    
    return {
        "status": "connected" if is_valid else "token_invalid",
        "subdomain": credentials.subdomain,
        "apicp": credentials.apicp,
        "last_refreshed": credentials.last_refreshed.isoformat() if credentials.last_refreshed else None,
        "created_at": credentials.created_at.isoformat(),
        "token_valid": is_valid,
        "message": "ShareFile connection is healthy" if is_valid else "ShareFile token needs refresh"
    }

@router.post("/sharefile/callback")
async def sharefile_oauth_callback(
    code: str,
    subdomain: str,
    apicp: str,
    appcp: str = None,
    state: str = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Handle ShareFile OAuth2 callback and store credentials"""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    sf_api = ShareFileAPI()
    
    # Exchange code for tokens
    success = sf_api.exchange_code_for_token(code, subdomain, apicp, appcp or apicp)
    
    if success:
        # Store credentials in database
        from app.models.sharefile import ShareFileCredentials
        
        # Remove any existing organization-wide credentials
        db.query(ShareFileCredentials).filter(
            ShareFileCredentials.organization_wide == True
        ).delete()
        
        # Store new organization-wide credentials
        credentials = ShareFileCredentials(
            user_id=None,  # NULL for organization-wide
            created_by_user_id=current_user.id,  # Track who set it up
            organization_wide=True,
            access_token=sf_api.access_token,
            refresh_token=sf_api.refresh_token,
            subdomain=sf_api.subdomain,
            apicp=sf_api.apicp,
            appcp=sf_api.appcp
        )
        
        db.add(credentials)
        db.commit()
        
        # Test the connection
        home_folder = sf_api.get_home_folder()
        
        return {
            "status": "success",
            "message": "ShareFile authentication successful and credentials stored",
            "subdomain": subdomain,
            "apicp": apicp,
            "home_folder": home_folder,
            "credentials_stored": True
        }
    else:
        return {
            "status": "error",
            "message": "Failed to exchange authorization code for tokens"
        }

@router.get("/sharefile/test")
async def test_sharefile_connection(current_user: User = Depends(get_current_user)):
    """Test ShareFile API connection - requires OAuth2 setup first"""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    return {
        "status": "oauth2_required",
        "message": "ShareFile now uses OAuth2 authentication. Use /admin/sharefile/auth-url to get started.",
        "instructions": [
            "1. Call /admin/sharefile/auth-url to get authorization URL",
            "2. Visit the URL to authorize DocuSpa",
            "3. ShareFile will redirect with authorization code",
            "4. Use /admin/sharefile/callback with the code to complete setup"
        ]
    }

@router.get("/sharefile/files")
async def get_sharefile_files(
    folder_id: str = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get ShareFile files and folders with automatic token refresh"""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    # Get organization-wide ShareFile credentials (shared by all admins)
    from app.models.sharefile import ShareFileCredentials
    
    credentials = db.query(ShareFileCredentials).filter(
        ShareFileCredentials.organization_wide == True,
        ShareFileCredentials.is_active == True
    ).first()
    
    if not credentials:
        return {
            "status": "not_authenticated",
            "message": "No organization-wide ShareFile credentials found. Please complete OAuth2 setup first.",
            "files": [],
            "folders": []
        }
    
    # Initialize ShareFile API with stored credentials
    sf_api = ShareFileAPI()
    sf_api.access_token = credentials.access_token
    sf_api.refresh_token = credentials.refresh_token
    sf_api.subdomain = credentials.subdomain
    sf_api.apicp = credentials.apicp
    sf_api.appcp = credentials.appcp
    
    # Test token validity and attempt refresh if needed
    token_valid = sf_api.ensure_valid_token(db, current_user.id)
    
    # If token validation fails, provide detailed error information
    if not token_valid:
        return {
            "status": "authentication_failed",
            "message": "ShareFile token validation failed. This could be due to expired credentials or API connectivity issues.",
            "debug_info": {
                "subdomain": credentials.subdomain,
                "apicp": credentials.apicp,
                "has_refresh_token": bool(credentials.refresh_token),
                "last_refreshed": credentials.last_refreshed.isoformat() if credentials.last_refreshed else None
            },
            "recommendation": "Try using the 'Refresh Token' button or reconnect your ShareFile account if the issue persists.",
            "files": [],
            "folders": []
        }
    
    # Get files and folders
    try:
        if folder_id:
            # Getting specific folder contents
            items_response = sf_api.get_items(folder_id)
        else:
            # Getting home folder and its contents
            home_folder = sf_api.get_home_folder()
            if home_folder and home_folder.get('Id'):
                # Get children of the home folder
                items_response = sf_api.get_items(home_folder['Id'])
            else:
                items_response = None
        
        if not items_response:
            return {
                "status": "error",
                "message": "Failed to retrieve ShareFile items. Your token may have expired.",
                "files": [],
                "folders": []
            }
        
        # Handle different response formats from ShareFile API
        items = []
        if isinstance(items_response, dict):
            # Standard API response with 'value' array
            items = items_response.get('value', [])
            # Some responses might have 'Children' instead
            if not items:
                items = items_response.get('Children', [])
            # If still no items, check if the response itself is the item list
            if not items and 'Id' in items_response:
                items = [items_response]
        elif isinstance(items_response, list):
            # Direct array response
            items = items_response
        
        # Debug logging (remove in production)
        print(f"ShareFile API Debug: Got {len(items)} items, response type: {type(items_response)}")
        if items:
            for item in items[:3]:  # Log first 3 items
                print(f"  Item: {item.get('Name')} (Type: {item.get('Type')}, Size: {item.get('FileSizeBytes', 'N/A')})")
        
        files = []
        folders = []
        
        for item in items:
            # Get item type - ShareFile uses different type values and field names
            item_type = item.get('Type', '').lower()
            
            # ShareFile sometimes uses different field names for type detection
            if not item_type:
                # Check for odata.type field (common in ShareFile API)
                odata_type = item.get('odata.type', item.get('@odata.type', ''))
                if 'folder' in odata_type.lower():
                    item_type = 'folder'
                elif 'file' in odata_type.lower():
                    item_type = 'file'
                # Check if item has children (indicates folder)
                elif 'Children' in item or item.get('HasChildren', False):
                    item_type = 'folder'
                # Check file extension (indicates file)
                elif '.' in item.get('Name', ''):
                    item_type = 'file'
                # Check if FileSizeBytes exists and is > 0 (usually files)
                elif item.get('FileSizeBytes', 0) > 0:
                    item_type = 'file'
                else:
                    # Default to file if we can't determine
                    item_type = 'file'
            
            item_name = item.get('Name', 'Unknown')
            item_size = item.get('FileSizeBytes', 0)
            
            # Format size for display
            if item_size > 0:
                if item_size >= 1024 * 1024 * 1024:  # GB
                    size_display = f"{item_size / (1024 * 1024 * 1024):.2f} GB"
                elif item_size >= 1024 * 1024:  # MB
                    size_display = f"{item_size / (1024 * 1024):.2f} MB"
                elif item_size >= 1024:  # KB
                    size_display = f"{item_size / 1024:.2f} KB"
                else:  # Bytes
                    size_display = f"{item_size} bytes"
            else:
                size_display = "Unknown size"
            
            # Format dates
            created_date = item.get('CreationDate', '')
            modified_date = item.get('LastWriteTime', item.get('ModificationDate', ''))
            
            try:
                if created_date:
                    from datetime import datetime
                    created_dt = datetime.fromisoformat(created_date.replace('Z', '+00:00'))
                    created_display = created_dt.strftime('%Y-%m-%d %H:%M')
                else:
                    created_display = 'Unknown'
            except:
                created_display = 'Unknown'
            
            try:
                if modified_date:
                    from datetime import datetime
                    modified_dt = datetime.fromisoformat(modified_date.replace('Z', '+00:00'))
                    modified_display = modified_dt.strftime('%Y-%m-%d %H:%M')
                else:
                    modified_display = 'Unknown'
            except:
                modified_display = 'Unknown'
            
            item_data = {
                "id": item.get('Id'),
                "name": item_name,
                "type": item.get('Type'),
                "size": item_size,
                "size_display": size_display,
                "created": created_display,
                "modified": modified_display,
                "download_url": item.get('url', item.get('Uri')) if item_type != 'folder' else None,
                "is_folder": item_type == 'folder'
            }
            
            # Categorize items - ShareFile folders have Type="Folder"
            if item_type == 'folder':
                folders.append(item_data)
            else:
                # Everything else is treated as a file
                files.append(item_data)
        
        return {
            "status": "success", 
            "files": files,
            "folders": folders,
            "total_items": len(items),
            "current_folder_id": folder_id,
            "token_refreshed": sf_api.access_token != credentials.access_token,
            "last_checked": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        return {
            "status": "error",
            "message": f"Error accessing ShareFile: {str(e)}",
            "files": [],
            "folders": []
        }

@router.post("/sharefile/refresh-token")
async def refresh_sharefile_token(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Manually refresh ShareFile access token with enhanced feedback"""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    from app.models.sharefile import ShareFileCredentials
    from app.services.token_refresh import token_refresh_service
    
    # Get organization-wide credentials
    credentials = db.query(ShareFileCredentials).filter(
        ShareFileCredentials.organization_wide == True,
        ShareFileCredentials.is_active == True
    ).first()
    
    if not credentials:
        raise HTTPException(status_code=404, detail="No organization-wide ShareFile credentials found")
    
    # Use the background service for consistent refresh logic
    result = await token_refresh_service.force_refresh_user_token(current_user.id)
    
    return result

@router.get("/sharefile/refresh-status")
async def get_refresh_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get ShareFile token refresh status and history"""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    from app.models.sharefile import ShareFileCredentials
    
    # Get organization-wide credentials
    credentials = db.query(ShareFileCredentials).filter(
        ShareFileCredentials.organization_wide == True,
        ShareFileCredentials.is_active == True
    ).first()
    
    if not credentials:
        return {
            "status": "not_found",
            "message": "No organization-wide ShareFile credentials found"
        }
    
    # Calculate time until next refresh
    next_refresh = None
    if credentials.last_refreshed:
        next_refresh_time = credentials.last_refreshed + timedelta(hours=4)
        next_refresh = next_refresh_time.isoformat()
    
    return {
        "status": "found",
        "auto_refresh_enabled": credentials.auto_refresh,
        "last_refreshed": credentials.last_refreshed.isoformat() if credentials.last_refreshed else None,
        "refresh_count": credentials.refresh_count,
        "expires_at": credentials.expires_at.isoformat() if credentials.expires_at else None,
        "next_auto_refresh": next_refresh,
        "created_at": credentials.created_at.isoformat(),
        "is_active": credentials.is_active
    }

@router.get("/sharefile/test-connection")
async def test_sharefile_connection(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Test ShareFile API connection without fetching files"""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    from app.models.sharefile import ShareFileCredentials
    
    # Get organization-wide credentials
    credentials = db.query(ShareFileCredentials).filter(
        ShareFileCredentials.organization_wide == True,
        ShareFileCredentials.is_active == True
    ).first()
    
    if not credentials:
        return {
            "status": "not_authenticated",
            "message": "No organization-wide ShareFile credentials found. Please complete OAuth2 setup first."
        }
    
    # Initialize ShareFile API with stored credentials
    sf_api = ShareFileAPI()
    sf_api.access_token = credentials.access_token
    sf_api.refresh_token = credentials.refresh_token
    sf_api.subdomain = credentials.subdomain
    sf_api.apicp = credentials.apicp
    sf_api.appcp = credentials.appcp
    
    # Test basic API connectivity
    try:
        # Try to get home folder info (minimal API call)
        home_response = sf_api.get_home_folder()
        
        if home_response:
            return {
                "status": "success",
                "message": "ShareFile connection is working perfectly!",
                "home_folder": {
                    "id": home_response.get('Id'),
                    "name": home_response.get('Name'),
                    "url": home_response.get('url')
                },
                "connection_details": {
                    "subdomain": credentials.subdomain,
                    "apicp": credentials.apicp,
                    "last_refreshed": credentials.last_refreshed.isoformat() if credentials.last_refreshed else None
                }
            }
        else:
            return {
                "status": "error",
                "message": "ShareFile API returned empty response. Connection may be unstable.",
                "debug_info": {
                    "subdomain": credentials.subdomain,
                    "apicp": credentials.apicp,
                    "endpoint_tested": f"https://{credentials.subdomain}.{credentials.apicp}/sf/v3/Items(home)"
                }
            }
            
    except Exception as e:
        return {
            "status": "error",
            "message": f"ShareFile API connection failed: {str(e)}",
            "debug_info": {
                "subdomain": credentials.subdomain,
                "apicp": credentials.apicp,
                "endpoint_tested": f"https://{credentials.subdomain}.{credentials.apicp}/sf/v3/Items(home)",
                "error_type": type(e).__name__
            },
            "recommendation": "Check your ShareFile account status and try refreshing the token"
        }

@router.get("/sharefile/folders") 
async def get_sharefile_folders(current_user: User = Depends(get_current_user)):
    """Get ShareFile folder structure for document organization"""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    return {
        "folders": [],
        "message": "ShareFile folders will be available after implementing persistent OAuth2 token storage"
    }