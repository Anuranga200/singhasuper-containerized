# Complete Full-Stack Deployment Guide

## 🎯 Overview

Your Singha Loyalty System has **TWO separate parts** that need deployment:

```
┌─────────────────────────────────────────────────────────┐
│                    YOUR PROJECT                          │
│                                                           │
│  1. Backend (server/)  → Express.js API                 │
│  2. Frontend (root/)   → React + Vite                   │
│                                                           │
│  They are SEPARATE and deploy SEPARATELY                │
└─────────────────────────────────────────────────────────┘
```

---

## 📊 Deployment Status

### ✅ Backend (Already Deployed)

**What:** Express.js API server
**Where:** AWS ECS Fargate
**Database:** RDS MySQL
**Load Balancer:** Application Load Balancer
**Cost:** ~$45-62/month

**Access:** `http://[your-alb-dns]/api`

**Guides:**
- `CONSOLE_DEPLOYMENT_GUIDE.md` - Step-by-step AWS Console
- `deploy.sh` - Automated script
- `server/README.md` - Backend documentation

---

### ⚠️ Frontend (Needs Deployment)

**What:** React application (UI)
**Where:** AWS S3 + CloudFront (recommended)
**Cost:** ~$1-5/month

**Access:** `https://[your-cloudfront-url]`

**Guide:**
- `FRONTEND_DEPLOYMENT_GUIDE.md` - Complete frontend deployment

---

## 🚀 Quick Deployment Summary

### Backend Deployment (Already Done ✅)

```bash
# What you already did:
cd server
docker build -t singha-loyalty .
# ... pushed to ECR
# ... deployed to ECS
# ... connected to RDS
```

**Result:** API running at `http://[ALB-DNS]/api`

---

### Frontend Deployment (Do This Now ⚠️)

```bash
# Step 1: Build frontend
npm run build

# Step 2: Create S3 bucket
aws s3 mb s3://singha-loyalty-frontend

# Step 3: Upload files
aws s3 sync dist/ s3://singha-loyalty-frontend

# Step 4: Create CloudFront distribution
# (Use AWS Console - see FRONTEND_DEPLOYMENT_GUIDE.md)

# Step 5: Update backend CORS
# (Allow CloudFront URL - see guide)
```

**Result:** Frontend at `https://[CloudFront-URL]`

---

## 🏗️ Complete Architecture

### Current (Backend Only)
```
Users → ALB → ECS (Backend) → RDS
        ↑
        └─ API endpoint: http://alb-dns/api

Frontend: Running locally only ❌
```

### Target (Full Stack)
```
Users
  │
  ├─→ CloudFront → S3 (Frontend)
  │                  │
  │                  └─ React App
  │
  └─→ ALB → ECS (Backend) → RDS
            ↑
            └─ API endpoint: http://alb-dns/api
```

---

## 📋 Step-by-Step: Deploy Frontend

### Option 1: Quick Deploy (AWS Console)

**Time:** 30 minutes

1. **Build frontend:**
   ```bash
   npm run build
   ```

2. **Create S3 bucket:**
   - Go to S3 → Create bucket
   - Name: `singha-loyalty-frontend`
   - Uncheck "Block all public access"

3. **Upload files:**
   - Upload all files from `dist/` folder

4. **Create CloudFront:**
   - Go to CloudFront → Create distribution
   - Origin: Your S3 bucket
   - Wait 10-15 minutes

5. **Update backend CORS:**
   - Edit `server/src/index.js`
   - Add CloudFront URL to CORS origins
   - Redeploy backend

**Done!** Access at CloudFront URL

---

### Option 2: Automated Script

**Time:** 10 minutes

```bash
# Create deployment script
cat > deploy-frontend.sh << 'EOF'
#!/bin/bash
set -e

# Build
npm run build

# Deploy to S3
aws s3 sync dist/ s3://singha-loyalty-frontend --delete

# Invalidate CloudFront
aws cloudfront create-invalidation \
  --distribution-id [YOUR-ID] \
  --paths "/*"

echo "✅ Deployed!"
EOF

chmod +x deploy-frontend.sh
./deploy-frontend.sh
```

---

## 💰 Complete Cost Breakdown

### Monthly Costs

| Component | Service | Cost |
|-----------|---------|------|
| **Backend** | | |
| - API Server | ECS Fargate Spot | $5-8 |
| - Database | RDS MySQL (db.t3.micro) | $15-20 |
| - Load Balancer | ALB | $16 |
| - Container Registry | ECR | $1-2 |
| - CI/CD | CodePipeline | $1 |
| **Frontend** | | |
| - Static Hosting | S3 | $0.01 |
| - CDN | CloudFront | $1-5 |
| **Total** | | **$46-67/month** |

---

## 🔗 How They Connect

### 1. User Opens Website
```
User → CloudFront → S3 → React App Loads
```

### 2. React App Makes API Call
```
React App → ALB → ECS Backend → RDS → Response
```

### 3. Complete Flow
```
1. User visits: https://[cloudfront-url]
2. CloudFront serves React app from S3
3. React app loads in browser
4. User registers customer
5. React makes POST to: http://[alb-dns]/api/customers/register
6. Backend processes request
7. Backend saves to RDS
8. Backend returns loyalty number
9. React displays success message
```

---

## 🔧 Configuration

### Frontend Environment Variables

**File:** `.env.production`
```env
# Your backend API URL
VITE_API_BASE_URL=http://[YOUR-ALB-DNS]/api

# AWS Region
VITE_AWS_REGION=us-east-1
```

**Get your ALB DNS:**
```bash
aws cloudformation describe-stacks \
  --stack-name singha-loyalty-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`ALBEndpoint`].OutputValue' \
  --output text
```

---

### Backend CORS Configuration

**File:** `server/src/index.js`

```javascript
// Update CORS to allow your frontend
app.use(cors({
  origin: [
    'http://localhost:8080',  // Local dev
    'https://[YOUR-CLOUDFRONT-URL]',  // Production
  ],
  credentials: true
}));
```

**After updating, redeploy backend:**
```bash
cd server
docker build -t singha-loyalty .
# ... push to ECR and update ECS
```

---

## ✅ Verification Checklist

### Backend (Already Done)
- [x] ECS service running
- [x] RDS database accessible
- [x] ALB health checks passing
- [x] API endpoints responding
- [x] Database migrations run

### Frontend (Do This)
- [ ] Build succeeds
- [ ] Files uploaded to S3
- [ ] CloudFront distribution created
- [ ] CloudFront URL accessible
- [ ] React app loads
- [ ] API calls work (no CORS errors)
- [ ] Registration works
- [ ] Admin login works

---

## 🧪 Testing Complete System

### 1. Test Frontend Loads
```bash
# Open CloudFront URL
https://[your-cloudfront-url]

# Should see: Registration page
```

### 2. Test Customer Registration
```
1. Fill in form:
   - NIC: 123456789V
   - Name: Test User
   - Phone: 0771234567

2. Click Register

3. Should see: Success message with loyalty number
```

### 3. Test Admin Dashboard
```
1. Navigate to /admin

2. Login:
   - Email: admin@singha.com
   - Password: Admin@123

3. Should see: Customer list
```

### 4. Check Browser Console
```
F12 → Console tab

Should NOT see:
❌ CORS errors
❌ 404 errors
❌ Failed API calls

Should see:
✅ Successful API responses
✅ 200 status codes
```

---

## 🐛 Common Issues

### Issue 1: CORS Error

**Symptom:**
```
Access to fetch at 'http://alb-dns/api' from origin 'https://cloudfront-url' 
has been blocked by CORS policy
```

**Fix:**
1. Update backend CORS (see Configuration section)
2. Redeploy backend
3. Clear browser cache

---

### Issue 2: API Calls Fail

**Symptom:**
```
Failed to fetch
Network error
```

**Fix:**
1. Check `.env.production` has correct ALB URL
2. Rebuild frontend: `npm run build`
3. Redeploy to S3

---

### Issue 3: 404 on Page Refresh

**Symptom:**
- Navigate to `/admin` works
- Refresh page → 404 error

**Fix:**
1. Go to CloudFront → Error pages
2. Add custom error response:
   - 403 → /index.html (200)
   - 404 → /index.html (200)

---

### Issue 4: Old Version Showing

**Symptom:**
- Deployed new version
- Still seeing old version

**Fix:**
```bash
# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id [YOUR-ID] \
  --paths "/*"
```

---

## 📚 Documentation Reference

### Deployment Guides
- **CONSOLE_DEPLOYMENT_GUIDE.md** - Backend deployment (AWS Console)
- **FRONTEND_DEPLOYMENT_GUIDE.md** - Frontend deployment (detailed)
- **DEPLOYMENT.md** - Comprehensive deployment guide
- **QUICKSTART.md** - Quick reference

### Architecture & Planning
- **ARCHITECTURE.md** - System architecture
- **VISUAL_GUIDE.md** - Visual diagrams
- **PROJECT_TRANSFORMATION.md** - What changed

### Quality & Testing
- **TECH_LEAD_ASSESSMENT.md** - Technical review
- **QA_STRATEGY.md** - Testing strategy
- **QA_IMPLEMENTATION_GUIDE.md** - Testing implementation

---

## 🎯 Next Steps

### Immediate (This Week)
1. [ ] Deploy frontend to S3 + CloudFront
2. [ ] Update backend CORS
3. [ ] Test complete system
4. [ ] Verify all features work

### Short-term (Next Week)
1. [ ] Add custom domain (optional)
2. [ ] Setup frontend CI/CD
3. [ ] Configure monitoring
4. [ ] Add analytics

### Long-term (Next Month)
1. [ ] Implement testing (see QA guides)
2. [ ] Add performance monitoring
3. [ ] Security hardening
4. [ ] Backup automation

---

## 💡 Pro Tips

### 1. Separate Deployments
- Backend and frontend deploy independently
- Update one without affecting the other
- Faster deployments

### 2. Environment Variables
- Backend: Environment variables in ECS task definition
- Frontend: Build-time variables in `.env.production`
- Never commit secrets!

### 3. Caching Strategy
- CloudFront caches frontend (fast loading)
- S3 serves static files (cheap)
- ALB routes API calls (dynamic)

### 4. Cost Optimization
- Use CloudFront (cheaper than ALB for static files)
- Enable S3 lifecycle policies
- Use Fargate Spot for backend (70% savings)

---

## 🎉 Success!

When everything is deployed:

```
✅ Backend API: http://[alb-dns]/api
✅ Frontend: https://[cloudfront-url]
✅ Database: RDS MySQL
✅ CDN: CloudFront (global)
✅ SSL: HTTPS enabled
✅ Cost: ~$50-70/month
✅ Scalable: Handles traffic spikes
✅ Production-ready: Yes!
```

---

## 📞 Quick Commands

### Check Backend Status
```bash
aws ecs describe-services \
  --cluster singha-loyalty-cluster \
  --services singha-loyalty-service
```

### Deploy Frontend
```bash
npm run build
aws s3 sync dist/ s3://singha-loyalty-frontend
```

### Invalidate Cache
```bash
aws cloudfront create-invalidation \
  --distribution-id [ID] \
  --paths "/*"
```

### View Logs
```bash
aws logs tail /ecs/singha-loyalty --follow
```

---

## ✅ Final Checklist

- [ ] Backend deployed and running
- [ ] Frontend deployed to S3
- [ ] CloudFront distribution created
- [ ] CORS configured correctly
- [ ] All features tested
- [ ] No console errors
- [ ] Performance acceptable
- [ ] Monitoring configured
- [ ] Backup strategy in place
- [ ] Documentation updated

---

**You now have a complete full-stack deployment guide!**

**Start with:** `FRONTEND_DEPLOYMENT_GUIDE.md` for detailed frontend deployment steps.

**Questions?** All guides are in your project root directory.

Good luck! 🚀
