from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List

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

@router.get("/sharefile/test")
async def test_sharefile_connection(current_user: User = Depends(get_current_user)):
    """Test ShareFile API connection"""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    sf_api = ShareFileAPI()
    success = sf_api.authenticate()
    
    if success:
        items = sf_api.get_items()
        return {
            "status": "connected",
            "authenticated": True,
            "sample_items": items
        }
    else:
        return {
            "status": "failed",
            "authenticated": False,
            "error": "Could not authenticate with ShareFile"
        }