## **✅ Developer-Focused PRD — SpaDoc Onboarding Portal (MVP · Linear Flow · Redirect-Based Signing)**

---

# **1\. System Architecture Overview**

| Layer | Technology (Proposed) | Responsibilities |
| ----- | ----- | ----- |
| Frontend | React (SPA) | Dashboards (Spa \+ Admin), forms, redirects |
| Backend API | Node.js (Express) or Python FastAPI | Auth, onboarding state machine, ShareFile \+ Stripe integration |
| Database | PostgreSQL (RDS) | User data, onboarding state, document metadata |
| File Storage | AWS S3 (encrypted) | Archive of signed docs if mirrored |
| External APIs | ShareFile (Doc signing), Stripe (Payment setup) | E-sign \+ billing |
| Notifications | AWS SES or SendGrid | Email triggers |
| Auth | JWT with refresh tokens | Role-based access: `spa_user` / `admin` |

---

# **2\. Data Models / ERD**

`User`  
`- id (uuid, pk)`  
`- role (enum: "admin", "spa_user")`  
`- email`  
`- password_hash`  
`- spa_id (nullable if admin)`  
`- created_at`

`Spa`  
`- id (uuid, pk)`  
`- name`  
`- contact_email`  
`- status (enum: "invited", "info_submitted", "documents_signed", "payment_setup", "completed")`  
`- created_at`

`OnboardingInfo`  
`- id (uuid)`  
`- spa_id (fk)`  
`- business_name`  
`- address`  
`- license_number`  
`- submitted_at`

`Document`  
`- id (uuid)`  
`- spa_id (fk)`  
`- sharefile_id (string)`  
`- name`  
`- status (enum: "pending", "signed", "failed")`  
`- signed_at`

`PaymentMethod`  
`- id (uuid)`  
`- spa_id (fk)`  
`- stripe_customer_id`  
`- stripe_payment_method_id`  
`- setup_at`

---

# **3\. API Endpoints**

### **Auth**

| Method | Endpoint | Description |
| ----- | ----- | ----- |
| POST | /auth/register-admin | (One-time setup / internal only) |
| POST | /auth/invite-spa | Admin triggers invite |
| POST | /auth/login | Email \+ password → JWT |
| POST | /auth/reset-password | Email send |
| POST | /auth/reset-password/confirm | Reset with token |

---

### **Spa Onboarding Flow**

| Method | Endpoint | Role | Description |
| ----- | ----- | ----- | ----- |
| GET | /spa/me | Spa\_User | Get current spa profile & onboarding status |
| POST | /spa/info | Spa\_User | Submit onboarding info (moves to `info_submitted`) |
| GET | /spa/documents | Spa\_User | List assigned documents \+ link to sign |
| POST | /spa/documents/:id/redirect-url | Spa\_User | Backend generates ShareFile signing URL & returns it |
| POST | /spa/payment/setup-intent | Spa\_User | Start payment setup (Stripe SetupIntent) |
| POST | /spa/payment/confirm | Spa\_User | Confirm/setup success (moves to `payment_setup`) |
| GET | /spa/status | Spa\_User | Show progress state |

---

### **Admin Dashboard**

| Method | Endpoint | Description |
| ----- | ----- | ----- |
| GET | /admin/spas | List all spas \+ current states |
| GET | /admin/spas/:id | Detailed view |
| POST | /admin/spas/:id/upload-document | Bind ShareFile doc to spa |
| POST | /admin/spas/:id/send-reminder | Trigger email |

---

# **4\. State Machine / Workflow**

`invited → info_submitted → documents_signed → payment_setup → completed`

| Trigger | From → To | Logic |
| ----- | ----- | ----- |
| Spa submits OnboardingInfo | invited → info\_submitted |  |
| All documents \= signed | info\_submitted → documents\_signed | Poll or webhook |
| Stripe payment added | documents\_signed → payment\_setup |  |
| Auto-check: all criteria met | payment\_setup → completed | Send final email |

---

# **5\. ShareFile Integration**

* Authenticate using OAuth Client Credentials.

* Admin selects document from ShareFile or uploads.

* Backend stores `sharefile_id` for each Document.

* Signing Flow:

  * Backend calls ShareFile **Create Signing Link**.

  * API responds with URL → returned to frontend → redirect user.

* Completion Detection:

  * **Webhook (preferred)** → `/webhooks/sharefile/document-signed`

  * OR periodic polling (`GET /documents/:id/status`)

---

# **6\. Stripe Integration (Payment Setup)**

* Use **Stripe Customer \+ SetupIntent**.

* Frontend collects payment using `stripe.js`.

* On success, webhook calls `/webhooks/stripe/payment-setup`.

* Backend stores `payment_method_id` and transitions state.

---

# **7\. Notification Triggers**

| Event | Email Recipients | Subject Example |
| ----- | ----- | ----- |
| Invite Sent | Spa User | “Welcome to SpaDoc — Begin Your Setup” |
| Info Submitted | Admin | “Spa {name} submitted onboarding details” |
| Doc Ready to Sign | Spa User | “Sign Your SpaDoc Documents” |
| All Docs Signed | Admin \+ Spa | “Documents Complete — Finalize Payment” |
| Payment Setup | Admin \+ Spa | “Onboarding Complete — You're Ready to Go\!” |

