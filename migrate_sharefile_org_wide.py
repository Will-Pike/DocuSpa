"""
Migration script to make ShareFile credentials organization-wide
"""
import os
import sys
from sqlalchemy import text
from dotenv import load_dotenv

# Add the project root to the Python path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import engine

load_dotenv()

def migrate_sharefile_to_organization_wide():
    """Make ShareFile credentials organization-wide instead of user-specific"""
    
    migrations = [
        # Add organization_wide column
        "ALTER TABLE sharefile_credentials ADD COLUMN organization_wide BOOLEAN DEFAULT FALSE",
        
        # Add created_by_user_id to track who set up the credentials
        "ALTER TABLE sharefile_credentials ADD COLUMN created_by_user_id CHAR(36) DEFAULT NULL",
        
        # Copy existing user_id to created_by_user_id for existing records
        "UPDATE sharefile_credentials SET created_by_user_id = user_id WHERE created_by_user_id IS NULL",
        
        # Mark existing credentials as organization-wide
        "UPDATE sharefile_credentials SET organization_wide = TRUE",
        
        # Make user_id nullable (will be NULL for organization-wide credentials)
        "ALTER TABLE sharefile_credentials MODIFY COLUMN user_id CHAR(36) DEFAULT NULL"
    ]
    
    with engine.connect() as connection:
        for migration in migrations:
            try:
                connection.execute(text(migration))
                connection.commit()
                print(f"✅ Executed: {migration}")
            except Exception as e:
                if "Duplicate column name" in str(e):
                    print(f"⏭️  Skipped (already exists): {migration}")
                else:
                    print(f"❌ Error: {migration} - {e}")
                    
        print("\n🎉 ShareFile credentials migration to organization-wide completed!")

if __name__ == "__main__":
    migrate_sharefile_to_organization_wide()