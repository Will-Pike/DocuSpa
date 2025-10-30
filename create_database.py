#!/usr/bin/env python3
"""
Create the docuspa-db database in RDS
"""

import os
import sys
from dotenv import load_dotenv
import pymysql
from urllib.parse import unquote_plus

# Load environment variables
load_dotenv()

def create_database():
    """Create the docuspa-db database"""
    database_url = os.getenv("DATABASE_URL")
    
    if not database_url:
        print("❌ DATABASE_URL not found in .env file")
        return False
    
    try:
        # Parse the database URL manually due to special characters in password
        url_without_protocol = database_url.replace("mysql+pymysql://", "")
        
        # Split at the @ to separate credentials from host info
        credentials, host_info = url_without_protocol.split("@", 1)
        
        # Split credentials to get username and password
        username, password = credentials.split(":", 1)
        password = unquote_plus(password)
        
        # Split host info to get host:port and database
        host_port, database_name = host_info.split("/", 1)
        host, port_str = host_port.split(":")
        port = int(port_str)
        
        print(f"🔗 Connecting to MySQL server:")
        print(f"   Host: {host}")
        print(f"   Port: {port}")
        print(f"   Username: {username}")
        print()
        
        # Connect without specifying a database
        connection = pymysql.connect(
            host=host,
            port=port,
            user=username,
            password=password,
            charset='utf8mb4'
        )
        
        print("✅ Connected to MySQL server!")
        
        # Create the database
        with connection.cursor() as cursor:
            cursor.execute(f"CREATE DATABASE IF NOT EXISTS `{database_name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;")
            print(f"📊 Database '{database_name}' created successfully!")
            
            # Show databases to confirm
            cursor.execute("SHOW DATABASES;")
            databases = cursor.fetchall()
            print(f"📋 Available databases: {[db[0] for db in databases]}")
            
        connection.close()
        print("🎉 Database creation successful!")
        return True
        
    except Exception as e:
        print(f"❌ Database creation failed: {str(e)}")
        return False

if __name__ == "__main__":
    print("🛠️  Creating DocuSpa Database...")
    print("=" * 50)
    
    if create_database():
        print("\n✅ Now you can run: python test_db_connection.py")
        sys.exit(0)
    else:
        sys.exit(1)