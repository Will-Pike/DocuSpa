"""
Database migration script to add enhanced ShareFile credential fields
"""
import os
import sys
from sqlalchemy import text
from dotenv import load_dotenv

# Add the project root to the Python path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import engine

load_dotenv()

def migrate_sharefile_credentials():
    """Add new columns to sharefile_credentials table"""
    
    migrations = [
        "ALTER TABLE sharefile_credentials ADD COLUMN last_refreshed DATETIME DEFAULT NULL",
        "ALTER TABLE sharefile_credentials ADD COLUMN refresh_count INT DEFAULT 0",
        "ALTER TABLE sharefile_credentials ADD COLUMN is_active BOOLEAN DEFAULT TRUE",
        "ALTER TABLE sharefile_credentials ADD COLUMN auto_refresh BOOLEAN DEFAULT TRUE",
        "UPDATE sharefile_credentials SET refresh_count = 0 WHERE refresh_count IS NULL",
        "UPDATE sharefile_credentials SET is_active = TRUE WHERE is_active IS NULL",
        "UPDATE sharefile_credentials SET auto_refresh = TRUE WHERE auto_refresh IS NULL"
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
                    
        print("\n🎉 ShareFile credentials table migration completed!")

if __name__ == "__main__":
    migrate_sharefile_credentials()