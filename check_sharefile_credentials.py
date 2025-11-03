#!/usr/bin/env python3
"""
Verify ShareFile credentials are now organization-wide
"""

import os
from dotenv import load_dotenv
from app.database import SessionLocal
from app.models.sharefile import ShareFileCredentials

# Load environment variables
load_dotenv()

def check_sharefile_credentials():
    """Check current ShareFile credentials structure"""
    db = SessionLocal()
    
    try:
        # Get all ShareFile credentials
        all_credentials = db.query(ShareFileCredentials).all()
        
        print("🔍 ShareFile Credentials Analysis:")
        print(f"   Total credentials: {len(all_credentials)}")
        
        if not all_credentials:
            print("   ❌ No ShareFile credentials found")
            return
            
        for cred in all_credentials:
            print(f"\n📋 Credential ID: {cred.id}")
            print(f"   • Organization-wide: {cred.organization_wide}")
            print(f"   • User ID: {cred.user_id or 'NULL (organization-wide)'}")
            print(f"   • Created by: {cred.created_by_user_id or 'Unknown'}")
            print(f"   • Subdomain: {cred.subdomain}")
            print(f"   • API CP: {cred.apicp}")
            print(f"   • Active: {cred.is_active}")
            print(f"   • Auto-refresh: {cred.auto_refresh}")
            print(f"   • Last refreshed: {cred.last_refreshed or 'Never'}")
            
        # Check for organization-wide credentials
        org_wide = db.query(ShareFileCredentials).filter(
            ShareFileCredentials.organization_wide == True,
            ShareFileCredentials.is_active == True
        ).first()
        
        if org_wide:
            print(f"\n✅ Organization-wide credentials found!")
            print(f"   All admin users can now access ShareFile")
            print(f"   Subdomain: {org_wide.subdomain}")
            print(f"   Setup by user: {org_wide.created_by_user_id}")
        else:
            print(f"\n❌ No active organization-wide credentials found")
            
    except Exception as e:
        print(f"❌ Error checking credentials: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    check_sharefile_credentials()