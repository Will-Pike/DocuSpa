#!/usr/bin/env python3
"""
Direct database check for ShareFile credentials
"""

import pymysql
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv()

def check_credentials():
    """Check ShareFile credentials via direct MySQL connection"""
    try:
        # Database connection from environment
        db_host = "docuspa-db.cvy4mgkesrso.us-east-2.rds.amazonaws.com"
        db_name = "docuspa-db"  # Note: database name from URL
        db_user = "admin"
        # URL encoded password from .env
        db_password = "[NLtuTc)xA-my-U-r<XePARpH7x5"
        
        connection = pymysql.connect(
            host=db_host,
            user=db_user,
            password=db_password,
            database=db_name,
            charset='utf8mb4'
        )
        
        with connection.cursor() as cursor:
            # Check table structure
            cursor.execute("DESCRIBE sharefile_credentials")
            columns = cursor.fetchall()
            
            print("🔍 ShareFile Credentials Table Structure:")
            for col in columns:
                print(f"   {col[0]}: {col[1]} {col[2] or ''}")
            
            # Check actual data
            cursor.execute("""
                SELECT id, organization_wide, user_id, created_by_user_id, 
                       subdomain, is_active, auto_refresh
                FROM sharefile_credentials
            """)
            
            credentials = cursor.fetchall()
            
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
            cursor.execute("""
                SELECT COUNT(*) FROM sharefile_credentials 
                WHERE organization_wide = 1 AND is_active = 1
            """)
            org_wide_count = cursor.fetchone()[0]
            
            if org_wide_count > 0:
                print(f"\n✅ {org_wide_count} active organization-wide credential(s) found!")
                print("   All admin users can now access ShareFile")
            else:
                print(f"\n❌ No active organization-wide credentials found")
                
            # Also check admin users (try different table name)
            try:
                cursor.execute("SHOW TABLES LIKE '%admin%' OR SHOW TABLES LIKE '%user%'")
                tables = cursor.fetchall()
                print(f"\n🔍 Available tables with 'admin' or 'user': {[t[0] for t in tables]}")
                
                cursor.execute("SELECT id, email FROM adminusers")
                users = cursor.fetchall()
                print(f"\n👥 Admin Users ({len(users)}):")
                for user in users:
                    print(f"   • ID: {user[0]}, Email: {user[1]}")
            except Exception as e:
                print(f"\n⚠️  Could not fetch admin users: {e}")
                print("   (This doesn't affect ShareFile organization-wide setup)")
                
        connection.close()
        
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    check_credentials()