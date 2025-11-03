#!/usr/bin/env python3
"""
Minimal FastAPI app to test admin registration
"""

from fastapi import FastAPI, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
import os
from dotenv import load_dotenv

# Import our database and models
from app.database import get_db, Base, engine
from app.models.user import User, UserRole
from app.services.auth import get_password_hash

# Load environment variables
load_dotenv()

# Create database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(title="DocuSpa Test API")

class RegisterRequest(BaseModel):
    email: str
    password: str

@app.get("/")
async def root():
    return {"message": "DocuSpa Test API"}

@app.post("/register-admin")
async def register_admin(register_data: RegisterRequest, db: Session = Depends(get_db)):
    """Register a new admin user (for initial setup)"""
    
    # Check if admin already exists
    existing_user = db.query(User).filter(User.email == register_data.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User already exists"
        )
    
    hashed_password = get_password_hash(register_data.password)
    
    new_user = User(
        email=register_data.email,
        password_hash=hashed_password,
        role=UserRole.admin
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    return {"message": "Admin user created successfully"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)