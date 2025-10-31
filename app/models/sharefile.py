from sqlalchemy import Column, String, DateTime, Text, ForeignKey, Boolean, Integer
from sqlalchemy.dialects.mysql import CHAR
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base
import uuid

class ShareFileCredentials(Base):
    __tablename__ = "sharefile_credentials"
    
    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(CHAR(36), ForeignKey("users.id"), nullable=True)  # NULL for organization-wide credentials
    created_by_user_id = Column(CHAR(36), ForeignKey("users.id"), nullable=True)  # Track who created the credentials
    organization_wide = Column(Boolean, default=True)  # True for organization-wide credentials
    access_token = Column(Text, nullable=False)  # Encrypted in production
    refresh_token = Column(Text, nullable=True)  # Encrypted in production  
    subdomain = Column(String(100), nullable=False)
    apicp = Column(String(100), nullable=False)
    appcp = Column(String(100), nullable=False)
    expires_at = Column(DateTime, nullable=True)  # When access token expires (8 hours from creation)
    last_refreshed = Column(DateTime, nullable=True)  # When token was last refreshed
    refresh_count = Column(Integer, default=0)  # Track number of refreshes
    is_active = Column(Boolean, default=True)  # Whether credentials are active
    auto_refresh = Column(Boolean, default=True)  # Whether to auto-refresh tokens
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
    
    # Relationship back to user (optional for organization-wide)
    user = relationship("User", foreign_keys=[user_id])
    created_by_user = relationship("User", foreign_keys=[created_by_user_id])