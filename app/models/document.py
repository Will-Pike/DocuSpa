from sqlalchemy import Column, String, DateTime, Enum, ForeignKey
from sqlalchemy.dialects.mysql import CHAR
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base
import enum
import uuid

class DocumentStatus(enum.Enum):
    pending = "pending"
    signed = "signed"
    failed = "failed"

class Document(Base):
    __tablename__ = "documents"
    
    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    spa_id = Column(CHAR(36), ForeignKey("spas.id"), nullable=False)
    sharefile_id = Column(String(255), nullable=False)
    name = Column(String(255), nullable=False)
    status = Column(Enum(DocumentStatus), default=DocumentStatus.pending, nullable=False)
    signed_at = Column(DateTime, nullable=True)
    
    # Relationships
    spa = relationship("Spa", back_populates="documents")

class PaymentMethod(Base):
    __tablename__ = "payment_methods"
    
    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    spa_id = Column(CHAR(36), ForeignKey("spas.id"), nullable=False)
    stripe_customer_id = Column(String(255), nullable=False)
    stripe_payment_method_id = Column(String(255), nullable=False)
    setup_at = Column(DateTime, server_default=func.now())
    
    # Relationships
    spa = relationship("Spa", back_populates="payment_method")