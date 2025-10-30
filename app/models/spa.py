from sqlalchemy import Column, String, DateTime, Enum, Text, ForeignKey
from sqlalchemy.dialects.mysql import CHAR
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base
import enum
import uuid

class SpaStatus(enum.Enum):
    invited = "invited"
    info_submitted = "info_submitted"
    documents_signed = "documents_signed"
    payment_setup = "payment_setup"
    completed = "completed"

class Spa(Base):
    __tablename__ = "spas"
    
    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String(255), nullable=False)
    contact_email = Column(String(255), nullable=False)
    status = Column(Enum(SpaStatus), default=SpaStatus.invited, nullable=False)
    created_at = Column(DateTime, server_default=func.now())
    
    # Relationships
    onboarding_info = relationship("OnboardingInfo", back_populates="spa", uselist=False)
    documents = relationship("Document", back_populates="spa")
    payment_method = relationship("PaymentMethod", back_populates="spa", uselist=False)

class OnboardingInfo(Base):
    __tablename__ = "onboarding_info"
    
    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    spa_id = Column(CHAR(36), ForeignKey("spas.id"), nullable=False)
    business_name = Column(String(255), nullable=False)
    address = Column(Text, nullable=False)
    license_number = Column(String(100), nullable=False)
    submitted_at = Column(DateTime, server_default=func.now())
    
    # Relationships
    spa = relationship("Spa", back_populates="onboarding_info")