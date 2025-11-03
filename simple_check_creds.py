#!/usr/bin/env python3
"""
Simple check for ShareFile credentials
"""

import os
import sys
from pathlib import Path

# Add the project root to Python path
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

from dotenv import load_dotenv
load_dotenv()

from sqlalchemy import create_engine, text
from app.config import settings

def check_credentials():
    """Check ShareFile credentials via direct SQL"""
    try:
        engine = create_engine(settings.DATABASE_URL)
        
        with engine.connect() as conn:
            # Check table structure
            result = conn.execute(text("""
                DESCRIBE sharefile_credentials
            """))
            columns = [row[0] for row in result.fetchall()]
            
            print("🔍 ShareFile Credentials Table Structure:")
            print(f"   Columns: {', '.join(columns)}")
            
            # Check actual data
            result = conn.execute(text("""
                SELECT id, organization_wide, user_id, created_by_user_id, 
                       subdomain, is_active, auto_refresh
                FROM sharefile_credentials
            """))
            
            credentials = result.fetchall()
            
            print(f"\n📋 Found {len(credentials)} ShareFile credentials:")
            
            for cred in credentials:
                print(f"\n   • ID: {cred[0]}")
                print(f"   • Organization-wide: {cred[1]}")
                print(f"   • User ID: {cred[2] or 'NULL (organization-wide)'}")
                print(f"   • Created by: {cred[3] or 'Unknown'}")
                print(f"   • Subdomain: {cred[4]}")
                print(f"   • Active: {cred[5]}")
                print(f"   • Auto-refresh: {cred[6]}")
            
            # Check for organization-wide
            result = conn.execute(text("""
                SELECT COUNT(*) FROM sharefile_credentials 
                WHERE organization_wide = 1 AND is_active = 1
            """))
            org_wide_count = result.fetchone()[0]
            
            if org_wide_count > 0:
                print(f"\n✅ {org_wide_count} active organization-wide credential(s) found!")
                print("   All admin users can now access ShareFile")
            else:
                print(f"\n❌ No active organization-wide credentials found")
                
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    check_credentials()