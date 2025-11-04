from fastapi import FastAPI, Request, Depends, HTTPException, status
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse
import os
import asyncio
from contextlib import asynccontextmanager
from dotenv import load_dotenv

from app.database import engine, SessionLocal, Base
from app.routes import auth, admin, spa
from app.models import user, spa as spa_model, document, sharefile
from app.services.token_refresh import token_refresh_service

# Load environment variables
load_dotenv()

# Create database tables
Base.metadata.create_all(bind=engine)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Start the token refresh background service
    try:
        # Start token refresh service in the background
        asyncio.create_task(token_refresh_service.start_background_refresh())
        print("🔄 Started ShareFile token refresh background service")
    except Exception as e:
        print(f"Warning: Could not start token refresh service: {e}")
    
    yield
    
    # Shutdown: Stop the token refresh service
    try:
        await token_refresh_service.stop_background_refresh()
        print("🔄 Stopped ShareFile token refresh background service")
    except Exception as e:
        print(f"Warning: Error stopping token refresh service: {e}")

app = FastAPI(
    title="DocuSpa API", 
    version="1.0.0",
    description="Enhanced DocuSpa API with automatic ShareFile token refresh",
    lifespan=lifespan
)

# Mount static files
app.mount("/static", StaticFiles(directory="static"), name="static")

# Setup templates
templates = Jinja2Templates(directory="templates")

# Include routers
app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(admin.router, prefix="/admin", tags=["admin"])
app.include_router(spa.router, prefix="/spa", tags=["spa"])

# Root endpoint to serve the login page
@app.get("/", response_class=HTMLResponse)
async def root(request: Request):
    return templates.TemplateResponse("login.html", {"request": request})

@app.get("/dashboard", response_class=HTMLResponse)
async def dashboard(request: Request):
    return templates.TemplateResponse("dashboard.html", {"request": request})

@app.get("/sharefile-setup", response_class=HTMLResponse)
async def sharefile_setup(request: Request):
    return templates.TemplateResponse("sharefile_setup_enhanced.html", {"request": request})

@app.get("/sharefile-setup-old", response_class=HTMLResponse)
async def sharefile_setup_old(request: Request):
    return templates.TemplateResponse("sharefile_setup.html", {"request": request})

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "message": "DocuSpa is running"}

# Temporary debug endpoint to bypass auth issues
@app.get("/debug/token")
async def get_debug_token():
    """Temporary endpoint to get admin token for debugging ShareFile"""
    from app.services.auth import create_access_token
    from datetime import timedelta
    
    access_token_expires = timedelta(minutes=30)
    access_token = create_access_token(
        data={"sub": "admin@docuspa.com", "role": "admin"},
        expires_delta=access_token_expires
    )
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "message": "Debug token for ShareFile testing"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)