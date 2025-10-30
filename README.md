# DocuSpa - Document Onboarding Portal

A Python-based web application for managing spa client onboarding with ShareFile integration.

## Features

- Admin dashboard for managing client onboarding
- Integration with ShareFile API for document management
- MySQL database for storing client and document data
- JWT-based authentication
- Client status tracking through onboarding workflow

## Setup Instructions

### 1. Prerequisites

- Python 3.8+
- MySQL Server
- ShareFile API credentials

### 2. Installation

1. Clone the repository:
```bash
git clone https://github.com/Will-Pike/DocuSpa.git
cd DocuSpa
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Set up environment configuration:
```bash
cp .env.example .env
```
Then edit `.env` with your actual database and ShareFile credentials.

4. Set up MySQL database (AWS RDS recommended):
   - Create a MySQL RDS instance in AWS
   - Create a database named `docuspa`
   - Update the DATABASE_URL in `.env` with your RDS endpoint

4. Run the application:
```bash
python main.py
```

The application will be available at http://localhost:8000

### 3. First-time Setup

1. Create an admin user by sending a POST request to `/auth/register-admin`:
```bash
curl -X POST "http://localhost:8000/auth/register-admin" \
     -H "Content-Type: application/json" \
     -d '{"email": "admin@example.com", "password": "admin123"}'
```

2. Login at http://localhost:8000 with your admin credentials

3. Test ShareFile connection from the dashboard

## API Endpoints

### Authentication
- `POST /auth/login` - Admin login
- `POST /auth/register-admin` - Create admin user
- `GET /auth/me` - Get current user info

### Admin Dashboard
- `GET /admin/dashboard-stats` - Get dashboard statistics
- `GET /admin/spas` - List all spas
- `POST /admin/spas` - Create new spa
- `GET /admin/spas/{id}` - Get spa details
- `GET /admin/sharefile/test` - Test ShareFile connection

## Database Schema

The application uses the following main entities:
- **User**: Admin and spa user accounts
- **Spa**: Spa business information and onboarding status
- **OnboardingInfo**: Detailed spa business information
- **Document**: ShareFile document references
- **PaymentMethod**: Stripe payment setup information

## ShareFile Integration

The application integrates with ShareFile API using OAuth client credentials flow. Configure your ShareFile credentials in the `.env` file.

## Development

To add new features:
1. Add models in `app/models/`
2. Add routes in `app/routes/`
3. Add services in `app/services/`
4. Update frontend templates as needed

## Status Workflow

Spas progress through the following statuses:
1. `invited` - Initial invitation sent
2. `info_submitted` - Business information submitted
3. `documents_signed` - All documents signed via ShareFile
4. `payment_setup` - Payment method configured
5. `completed` - Onboarding complete