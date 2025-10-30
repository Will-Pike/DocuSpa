from sqlalchemy import Column, String, DateTime, Enum, Text
from sqlalchemy.dialects.mysql import CHAR
from sqlalchemy.sql import func
from app.database import Base
import enum
import uuid

class UserRole(enum.Enum):
    admin = "admin"
    spa_user = "spa_user"

class User(Base):
    __tablename__ = "users"
    
    id = Column(CHAR(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    role = Column(Enum(UserRole), nullable=False)
    email = Column(String(255), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    spa_id = Column(CHAR(36), nullable=True)  # Foreign key to Spa, nullable for admin
    created_at = Column(DateTime, server_default=func.now())