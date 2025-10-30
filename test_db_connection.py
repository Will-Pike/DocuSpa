#!/usr/bin/env python3
"""
Simple script to test MySQL RDS connection
Run this before starting the main application
"""

import os
import sys
from dotenv import load_dotenv
import pymysql
from urllib.parse import urlparse

# Load environment variables
load_dotenv()

def test_connection():
    """Test connection to MySQL RDS"""
    database_url = os.getenv("DATABASE_URL")
    
    if not database_url:
        print("❌ DATABASE_URL not found in .env file")
        return False
    
    try:
        # Parse the database URL manually due to special characters in password
        # Format: mysql+pymysql://username:password@host:port/database
        
        # Remove the protocol prefix
        url_without_protocol = database_url.replace("mysql+pymysql://", "")
        
        # Split at the @ to separate credentials from host info
        credentials, host_info = url_without_protocol.split("@", 1)
        
        # Split credentials to get username and password
        username, password = credentials.split(":", 1)
        
        # URL decode the password if it's encoded
        from urllib.parse import unquote_plus
        password = unquote_plus(password)
        
        # Split host info to get host:port and database
        host_port, database = host_info.split("/", 1)
        host, port_str = host_port.split(":")
        port = int(port_str)
        
        print(f"🔗 Attempting to connect to:")
        print(f"   Host: {host}")
        print(f"   Port: {port}")
        print(f"   Database: {database}")
        print(f"   Username: {username}")
        print()
        
        # Test connection
        connection = pymysql.connect(
            host=host,
            port=port,
            user=username,
            password=password,
            database=database,
            charset='utf8mb4'
        )
        
        print("✅ Successfully connected to MySQL RDS!")
        
        # Test query
        with connection.cursor() as cursor:
            cursor.execute("SELECT VERSION();")
            version = cursor.fetchone()
            print(f"📊 MySQL Version: {version[0]}")
            
            # Check if we can create tables (test permissions)
            cursor.execute("SHOW TABLES;")
            tables = cursor.fetchall()
            print(f"📋 Current tables: {len(tables)} found")
            
        connection.close()
        print("🎉 Connection test successful! You're ready to run the application.")
        return True
        
    except Exception as e:
        print(f"❌ Connection failed: {str(e)}")
        print()
        print("🔧 Troubleshooting tips:")
        print("1. Check your RDS endpoint in the .env file")
        print("2. Ensure your security group allows connections on port 3306")
        print("3. Verify your username and password")
        print("4. Make sure 'Public accessibility' is enabled on your RDS instance")
        print("5. Check if your IP address is whitelisted in the security group")
        return False

if __name__ == "__main__":
    print("🧪 Testing MySQL RDS Connection...")
    print("=" * 50)
    
    if test_connection():
        sys.exit(0)
    else:
        sys.exit(1)