from fastapi import APIRouter

router = APIRouter()

# Placeholder for spa user routes
@router.get("/me")
async def get_spa_profile():
    """Get current spa profile and onboarding status"""
    return {"message": "Spa profile endpoint - to be implemented"}