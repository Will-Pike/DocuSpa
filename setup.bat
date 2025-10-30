@echo off
echo Setting up DocuSpa application...

echo.
echo 1. Installing Python dependencies...
pip install -r requirements.txt

echo.
echo 2. Setting up database (make sure MySQL is running)...
echo Please ensure you have:
echo - MySQL server running
echo - Created a database named 'docuspa'
echo - Updated the DATABASE_URL in .env file

echo.
echo 3. Starting the application...
echo The application will be available at http://localhost:8000
echo.
echo To create an admin user, use:
echo curl -X POST "http://localhost:8000/auth/register-admin" -H "Content-Type: application/json" -d "{\"email\": \"admin@example.com\", \"password\": \"admin123\"}"
echo.

python main.py