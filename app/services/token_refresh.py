import asyncio
import logging
from datetime import datetime, timedelta
from typing import Optional
from sqlalchemy.orm import Session
from app.database import SessionLocal
from app.models.sharefile import ShareFileCredentials
from app.services.sharefile import ShareFileAPI

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class TokenRefreshService:
    def __init__(self):
        self.refresh_interval = 4 * 60 * 60  # 4 hours in seconds (ShareFile tokens last 8 hours)
        self.is_running = False
        
    async def start_background_refresh(self):
        """Start the background token refresh service"""
        if self.is_running:
            logger.info("Token refresh service already running")
            return
            
        self.is_running = True
        logger.info("Starting ShareFile token refresh background service")
        
        while self.is_running:
            try:
                await self.refresh_expiring_tokens()
                await asyncio.sleep(self.refresh_interval)
            except Exception as e:
                logger.error(f"Error in token refresh service: {e}")
                await asyncio.sleep(60)  # Wait 1 minute before retrying on error
                
    async def stop_background_refresh(self):
        """Stop the background token refresh service"""
        self.is_running = False
        logger.info("Stopping ShareFile token refresh background service")
        
    async def refresh_expiring_tokens(self):
        """Check for tokens that need refreshing and refresh them"""
        db = SessionLocal()
        try:
            # Find credentials that need refreshing (older than 4 hours or expired)
            cutoff_time = datetime.utcnow() - timedelta(hours=4)
            
            credentials_to_refresh = db.query(ShareFileCredentials).filter(
                ShareFileCredentials.is_active == True,
                ShareFileCredentials.auto_refresh == True,
                ShareFileCredentials.organization_wide == True,  # Only organization-wide credentials
                ShareFileCredentials.refresh_token.isnot(None)
            ).filter(
                # Refresh if last_refreshed is older than 4 hours or never refreshed
                (ShareFileCredentials.last_refreshed < cutoff_time) |
                (ShareFileCredentials.last_refreshed.is_(None))
            ).all()
            
            logger.info(f"Found {len(credentials_to_refresh)} ShareFile credentials that need refreshing")
            
            for credentials in credentials_to_refresh:
                try:
                    success = await self.refresh_credentials(credentials, db)
                    if success:
                        logger.info(f"Successfully refreshed organization-wide ShareFile token")
                    else:
                        logger.warning(f"Failed to refresh organization-wide ShareFile token")
                        
                except Exception as e:
                    logger.error(f"Error refreshing organization-wide ShareFile token: {e}")
                    
        except Exception as e:
            logger.error(f"Error in refresh_expiring_tokens: {e}")
        finally:
            db.close()
            
    async def refresh_credentials(self, credentials: ShareFileCredentials, db: Session) -> bool:
        """Refresh a specific set of credentials"""
        try:
            # Initialize ShareFile API
            sf_api = ShareFileAPI()
            sf_api.access_token = credentials.access_token
            sf_api.refresh_token = credentials.refresh_token
            sf_api.subdomain = credentials.subdomain
            sf_api.apicp = credentials.apicp
            sf_api.appcp = credentials.appcp
            
            # Attempt to refresh the token
            success = sf_api.refresh_access_token(db, credentials.user_id)
            
            if success:
                # Update credentials in database
                credentials.access_token = sf_api.access_token
                if sf_api.refresh_token:
                    credentials.refresh_token = sf_api.refresh_token
                credentials.last_refreshed = datetime.utcnow()
                credentials.refresh_count += 1
                
                # Set expiration time (ShareFile tokens typically last 8 hours)
                credentials.expires_at = datetime.utcnow() + timedelta(hours=8)
                
                db.commit()
                return True
            else:
                # Mark credentials as inactive if refresh fails multiple times
                if credentials.refresh_count > 10:
                    credentials.is_active = False
                    credentials.auto_refresh = False
                    db.commit()
                    logger.warning(f"Disabled auto-refresh for organization-wide ShareFile credentials after multiple failures")
                
                return False
                
        except Exception as e:
            logger.error(f"Exception in refresh_credentials: {e}")
            return False
            
    async def force_refresh_organization_token(self) -> dict:
        """Force refresh organization-wide ShareFile token"""
        db = SessionLocal()
        try:
            credentials = db.query(ShareFileCredentials).filter(
                ShareFileCredentials.organization_wide == True,
                ShareFileCredentials.is_active == True
            ).first()
            
            if not credentials:
                return {"status": "error", "message": "No active organization-wide ShareFile credentials found"}
                
            success = await self.refresh_credentials(credentials, db)
            
            if success:
                return {
                    "status": "success", 
                    "message": "Organization-wide ShareFile token refreshed successfully",
                    "refreshed_at": credentials.last_refreshed.isoformat(),
                    "expires_at": credentials.expires_at.isoformat() if credentials.expires_at else None
                }
            else:
                return {"status": "error", "message": "Organization-wide ShareFile token refresh failed"}
                
        except Exception as e:
            logger.error(f"Error in force_refresh_organization_token: {e}")
            return {"status": "error", "message": str(e)}
        finally:
            db.close()
    
    # Maintain backward compatibility
    async def force_refresh_user_token(self, user_id: str) -> dict:
        """Force refresh organization token (backward compatibility)"""
        return await self.force_refresh_organization_token()

# Global instance
token_refresh_service = TokenRefreshService()