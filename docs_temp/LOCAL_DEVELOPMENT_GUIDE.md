# Local Development Guide - Frontend & Backend

## 🎯 Overview

This guide helps you run the **complete application locally** for development:
- Frontend (React + Vite)
- Backend (Express.js API)
- Database (MySQL)

---

## 📋 Prerequisites

### Required Software

- [ ] **Node.js 18+** - [Download](https://nodejs.org/)
- [ ] **npm** or **yarn** - Comes with Node.js
- [ ] **MySQL 8.0+** - [Download](https://dev.mysql.com/downloads/)
- [ ] **Git** - [Download](https://git-scm.com/)

### Optional (Recommended)

- [ ] **Docker Desktop** - For containerized MySQL
- [ ] **MySQL Workbench** - GUI for database management
- [ ] **Postman** - API testing
- [ ] **VS Code** - Code editor

---

## 🚀 Quick Start (15 minutes)

### Option 1: Using Local MySQL

```bash
# 1. Clone repository
git clone <your-repo-url>
cd singha-loyalty-system

# 2. Install dependencies
npm install
cd server && npm install && cd ..

# 3. Setup database
mysql -u root -p
CREATE DATABASE singha_loyalty;
USE singha_loyalty;
source server/src/db/schema.sql;
exit;

# 4. Configure environment
cp server/.env.example server/.env
# Edit server/.env with your database credentials

cp .env.example .env
# Edit .env with backend URL

# 5. Start backend
cd server
npm run dev

# 6. Start frontend (new terminal)
cd ..
npm run dev

# Done! Open http://localhost:8080
```

---

### Option 2: Using Docker MySQL (Easier)

```bash
# 1. Clone and install
git clone <your-repo-url>
cd singha-loyalty-system
npm install
cd server && npm install && cd ..

# 2. Start MySQL with Docker
docker run -d \
  --name mysql-local \
  -e MYSQL_ROOT_PASSWORD=root \
  -e MYSQL_DATABASE=singha_loyalty \
  -p 3306:3306 \
  mysql:8.0

# Wait 30 seconds for MySQL to start

# 3. Run migrations
docker exec -i mysql-local mysql -uroot -proot singha_loyalty < server/src/db/schema.sql

# 4. Configure environment
cp server/.env.example server/.env
# Edit: DB_HOST=localhost, DB_PASSWORD=root

cp .env.example .env
# Edit: VITE_API_BASE_URL=http://localhost:3000/api

# 5. Start backend
cd server
npm run dev

# 6. Start frontend (new terminal)
cd ..
npm run dev

# Done! Open http://localhost:8080
```

---

## 📁 Project Structure

```
singha-loyalty-system/
├── src/                    # Frontend source
│   ├── components/         # React components
│   ├── pages/             # Page components
│   ├── services/          # API services
│   └── lib/               # Utilities
├── public/                # Static assets
├── server/                # Backend source
│   ├── src/
│   │   ├── controllers/   # Business logic
│   │   ├── routes/        # API routes
│   │   ├── middleware/    # Auth, validation
│   │   └── db/           # Database files
│   └── package.json
├── package.json           # Frontend dependencies
├── vite.config.ts        # Vite configuration
└── .env                  # Frontend environment variables
```

---

## 🔧 Detailed Setup

### Step 1: Install Node.js

**Check if installed:**
```bash
node --version  # Should be 18.x or higher
npm --version   # Should be 9.x or higher
```

**If not installed:**
- Download from https://nodejs.org/
- Install LTS version
- Restart terminal

---

### Step 2: Install MySQL

#### Option A: Local MySQL Installation

**Windows:**
1. Download MySQL Installer from https://dev.mysql.com/downloads/installer/
2. Run installer
3. Choose "Developer Default"
4. Set root password (remember this!)
5. Complete installation

**macOS:**
```bash
# Using Homebrew
brew install mysql
brew services start mysql

# Secure installation
mysql_secure_installation
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt update
sudo apt install mysql-server
sudo systemctl start mysql
sudo mysql_secure_installation
```

#### Option B: Docker MySQL (Recommended)

```bash
# Pull MySQL image
docker pull mysql:8.0

# Run MySQL container
docker run -d \
  --name mysql-dev \
  -e MYSQL_ROOT_PASSWORD=root \
  -e MYSQL_DATABASE=singha_loyalty \
  -p 3306:3306 \
  -v mysql-data:/var/lib/mysql \
  mysql:8.0

# Verify it's running
docker ps | grep mysql-dev
```

**Useful Docker commands:**
```bash
# Stop MySQL
docker stop mysql-dev

# Start MySQL
docker start mysql-dev

# Remove MySQL (data persists in volume)
docker rm mysql-dev

# Remove MySQL and data
docker rm mysql-dev
docker volume rm mysql-data
```

---

### Step 3: Setup Database

#### Create Database and Tables

**Using MySQL CLI:**
```bash
# Connect to MySQL
mysql -u root -p
# Enter your password

# Create database
CREATE DATABASE singha_loyalty;
USE singha_loyalty;

# Run schema
source server/src/db/schema.sql;

# Verify tables created
SHOW TABLES;
# Should show: admins, customers

# Exit
exit;
```

**Using Docker:**
```bash
# Copy schema file into container
docker cp server/src/db/schema.sql mysql-dev:/schema.sql

# Run schema
docker exec -i mysql-dev mysql -uroot -proot singha_loyalty < server/src/db/schema.sql

# Verify
docker exec -it mysql-dev mysql -uroot -proot -e "USE singha_loyalty; SHOW TABLES;"
```

**Using MySQL Workbench:**
1. Open MySQL Workbench
2. Connect to localhost:3306
3. Create new schema: `singha_loyalty`
4. Open `server/src/db/schema.sql`
5. Execute script

---

#### Seed Initial Data

```bash
cd server
npm run seed
```

**This creates:**
- Admin user: `admin@singha.com` / `Admin@123`
- 3 sample customers

---

### Step 4: Configure Environment Variables

#### Backend Configuration

**Create `server/.env`:**
```bash
cd server
cp .env.example .env
```

**Edit `server/.env`:**
```env
# Server
NODE_ENV=development
PORT=3000
CORS_ORIGIN=http://localhost:8080

# Database (Local MySQL)
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your-mysql-password
DB_NAME=singha_loyalty

# Database (Docker MySQL)
# DB_HOST=localhost
# DB_PORT=3306
# DB_USER=root
# DB_PASSWORD=root
# DB_NAME=singha_loyalty

# JWT Secrets (for development only)
JWT_SECRET=dev-jwt-secret-key-change-in-production
JWT_REFRESH_SECRET=dev-refresh-secret-key-change-in-production

# AWS (optional for local dev)
AWS_REGION=us-east-1
```

---

#### Frontend Configuration

**Create `.env`:**
```bash
# In project root
cp .env.example .env
```

**Edit `.env`:**
```env
# Backend API URL (local development)
VITE_API_BASE_URL=http://localhost:3000/api

# AWS Region
VITE_AWS_REGION=us-east-1

# Environment
VITE_ENV=development
```

---

### Step 5: Install Dependencies

#### Backend Dependencies

```bash
cd server
npm install
```

**Installs:**
- express
- mysql2
- jsonwebtoken
- bcryptjs
- cors
- helmet
- dotenv
- And more...

---

#### Frontend Dependencies

```bash
# In project root
npm install
```

**Installs:**
- react
- react-router-dom
- @tanstack/react-query
- tailwindcss
- shadcn/ui components
- And more...

---

### Step 6: Start Development Servers

#### Terminal 1: Backend Server

```bash
cd server
npm run dev
```

**Expected output:**
```
🚀 Server running on port 3000
📊 Environment: development
🔗 Health check: http://localhost:3000/health
✅ Database connected successfully
```

**Test backend:**
```bash
# In another terminal
curl http://localhost:3000/health
```

**Should return:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-31T10:00:00.000Z",
  "uptime": 5.123
}
```

---

#### Terminal 2: Frontend Server

```bash
# In project root
npm run dev
```

**Expected output:**
```
  VITE v5.4.19  ready in 1234 ms

  ➜  Local:   http://localhost:8080/
  ➜  Network: use --host to expose
  ➜  press h + enter to show help
```

**Open browser:**
```
http://localhost:8080
```

---

## 🧪 Testing Locally

### 1. Test Health Check

```bash
curl http://localhost:3000/health
```

**Expected:**
```json
{"status":"healthy","timestamp":"...","uptime":123}
```

---

### 2. Test Customer Registration

**Using curl:**
```bash
curl -X POST http://localhost:3000/api/customers/register \
  -H "Content-Type: application/json" \
  -d '{
    "nicNumber": "123456789V",
    "fullName": "Test Customer",
    "phoneNumber": "0771234567"
  }'
```

**Expected:**
```json
{
  "success": true,
  "loyaltyNumber": "1234"
}
```

**Using browser:**
1. Open http://localhost:8080/register
2. Fill in form
3. Submit
4. Should see success message

---

### 3. Test Admin Login

**Using curl:**
```bash
curl -X POST http://localhost:3000/api/admin/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@singha.com",
    "password": "Admin@123"
  }'
```

**Expected:**
```json
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Using browser:**
1. Open http://localhost:8080/admin
2. Login with: `admin@singha.com` / `Admin@123`
3. Should see dashboard

---

### 4. Test Protected Endpoint

```bash
# Save token from login
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# Get customers
curl http://localhost:3000/api/customers \
  -H "Authorization: Bearer $TOKEN"
```

**Expected:**
```json
{
  "customers": [...],
  "count": 3
}
```

---

## 🔍 Debugging

### Backend Debugging

#### Check Logs

Backend logs appear in the terminal where you ran `npm run dev`.

**Common log messages:**
```
✅ Database connected successfully
🚀 Server running on port 3000
POST /api/customers/register 200 45ms
GET /api/customers 401 12ms
```

---

#### Debug Database Connection

```bash
# Test MySQL connection
mysql -h localhost -u root -p -e "SELECT 1"

# Check if database exists
mysql -h localhost -u root -p -e "SHOW DATABASES LIKE 'singha_loyalty'"

# Check tables
mysql -h localhost -u root -p singha_loyalty -e "SHOW TABLES"

# Check data
mysql -h localhost -u root -p singha_loyalty -e "SELECT * FROM admins"
```

---

#### Common Backend Issues

**Issue: Port 3000 already in use**
```bash
# Find process using port 3000
# Windows
netstat -ano | findstr :3000

# macOS/Linux
lsof -i :3000

# Kill process
# Windows
taskkill /PID <PID> /F

# macOS/Linux
kill -9 <PID>
```

**Issue: Database connection failed**
```
Check:
1. MySQL is running
2. Database exists
3. Credentials in .env are correct
4. Port 3306 is not blocked
```

**Issue: Module not found**
```bash
# Reinstall dependencies
cd server
rm -rf node_modules package-lock.json
npm install
```

---

### Frontend Debugging

#### Check Browser Console

1. Open browser DevTools (F12)
2. Go to Console tab
3. Look for errors

**Common errors:**
```
❌ Failed to fetch
   → Backend not running

❌ CORS error
   → Backend CORS not configured

❌ 401 Unauthorized
   → Token expired or invalid
```

---

#### Check Network Tab

1. Open DevTools → Network tab
2. Perform action (register, login)
3. Check API calls

**What to look for:**
- Status codes (200 = success, 401 = unauthorized, 500 = server error)
- Request payload
- Response data
- Headers

---

#### Common Frontend Issues

**Issue: Port 8080 already in use**
```bash
# Vite will automatically try next port (8081, 8082, etc.)
# Or specify port:
npm run dev -- --port 5173
```

**Issue: API calls fail**
```
Check:
1. Backend is running (http://localhost:3000/health)
2. .env has correct API URL
3. No CORS errors in console
```

**Issue: White screen**
```bash
# Clear cache and rebuild
rm -rf node_modules .vite
npm install
npm run dev
```

---

## 🛠️ Development Workflow

### Making Changes

#### Backend Changes

1. **Edit code** in `server/src/`
2. **Save file** - Server auto-restarts (nodemon)
3. **Test** - Changes take effect immediately

**Example:**
```javascript
// server/src/controllers/customerController.js
export async function registerCustomer(req, res) {
  console.log('New registration:', req.body); // Add logging
  // ... rest of code
}
```

---

#### Frontend Changes

1. **Edit code** in `src/`
2. **Save file** - Browser auto-refreshes (HMR)
3. **Test** - Changes appear immediately

**Example:**
```tsx
// src/pages/Register.tsx
export default function Register() {
  console.log('Register page loaded'); // Add logging
  // ... rest of code
}
```

---

### Database Changes

#### Add New Table

1. **Edit** `server/src/db/schema.sql`
2. **Run migration:**
   ```bash
   mysql -u root -p singha_loyalty < server/src/db/schema.sql
   ```

#### Add Sample Data

1. **Edit** `server/src/db/seed.js`
2. **Run seed:**
   ```bash
   cd server
   npm run seed
   ```

---

### Testing Changes

#### Manual Testing

1. **Backend:**
   ```bash
   curl http://localhost:3000/api/endpoint
   ```

2. **Frontend:**
   - Open http://localhost:8080
   - Click through UI
   - Check console for errors

#### Automated Testing

```bash
# Backend tests (when implemented)
cd server
npm test

# Frontend tests (when implemented)
npm test
```

---

## 📦 Building for Production

### Build Frontend

```bash
npm run build
```

**Output:** `dist/` folder with optimized files

**Test production build:**
```bash
npm run preview
# Opens http://localhost:4173
```

---

### Build Backend

Backend doesn't need building (Node.js runs directly), but you can:

```bash
cd server

# Run in production mode
NODE_ENV=production npm start
```

---

## 🔄 Useful Commands

### Backend Commands

```bash
cd server

# Development (auto-restart)
npm run dev

# Production
npm start

# Run migrations
npm run migrate

# Seed database
npm run seed

# Run tests
npm test
```

---

### Frontend Commands

```bash
# Development server
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview

# Run tests
npm test

# Lint code
npm run lint
```

---

### Database Commands

```bash
# Connect to MySQL
mysql -u root -p

# Backup database
mysqldump -u root -p singha_loyalty > backup.sql

# Restore database
mysql -u root -p singha_loyalty < backup.sql

# Reset database
mysql -u root -p -e "DROP DATABASE singha_loyalty; CREATE DATABASE singha_loyalty;"
mysql -u root -p singha_loyalty < server/src/db/schema.sql
```

---

## 🎯 Development Tips

### 1. Use Nodemon for Backend

Already configured! Backend auto-restarts on file changes.

### 2. Use Hot Module Replacement (HMR)

Already configured! Frontend auto-refreshes on file changes.

### 3. Use Browser DevTools

- **Console:** Debug JavaScript
- **Network:** Monitor API calls
- **Application:** Check localStorage (JWT tokens)
- **React DevTools:** Inspect React components

### 4. Use Postman for API Testing

1. Import API collection
2. Test endpoints without UI
3. Save requests for reuse

### 5. Use MySQL Workbench

1. Visual database management
2. Run queries easily
3. View table data

---

## 🐛 Common Issues & Solutions

### Issue: "Cannot connect to MySQL"

**Solution:**
```bash
# Check MySQL is running
# Windows
sc query MySQL80

# macOS
brew services list | grep mysql

# Linux
sudo systemctl status mysql

# Docker
docker ps | grep mysql
```

---

### Issue: "Port already in use"

**Solution:**
```bash
# Change port in .env or vite.config.ts
# Or kill process using the port
```

---

### Issue: "Module not found"

**Solution:**
```bash
# Reinstall dependencies
rm -rf node_modules package-lock.json
npm install
```

---

### Issue: "CORS error"

**Solution:**
```javascript
// server/src/index.js
app.use(cors({
  origin: 'http://localhost:8080',  // Add your frontend URL
  credentials: true
}));
```

---

## ✅ Verification Checklist

- [ ] Node.js 18+ installed
- [ ] MySQL running
- [ ] Database created
- [ ] Tables created
- [ ] Sample data seeded
- [ ] Backend .env configured
- [ ] Frontend .env configured
- [ ] Backend dependencies installed
- [ ] Frontend dependencies installed
- [ ] Backend server starts (port 3000)
- [ ] Frontend server starts (port 8080)
- [ ] Health check works
- [ ] Customer registration works
- [ ] Admin login works
- [ ] No console errors

---

## 🎉 You're Ready!

Your local development environment is set up!

**Access:**
- Frontend: http://localhost:8080
- Backend API: http://localhost:3000/api
- Health Check: http://localhost:3000/health

**Credentials:**
- Admin: `admin@singha.com` / `Admin@123`

**Next steps:**
1. Make changes to code
2. Test locally
3. Commit to Git
4. Push to GitHub
5. Pipeline deploys automatically (if configured)

---

**Happy coding! 🚀**
