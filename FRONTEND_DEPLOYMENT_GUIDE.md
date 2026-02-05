# Frontend Deployment Guide - React Application

## 🎯 Overview

Your project has **two separate parts**:
1. **Backend** (Express.js API) - Already deployed to ECS ✅
2. **Frontend** (React + Vite) - Needs deployment ⚠️

This guide covers deploying the React frontend to AWS.

---

## 📊 Current Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    CURRENT (Backend Only)                │
│                                                           │
│  Users → ALB → ECS (Backend API) → RDS                  │
│                                                           │
│  Frontend: Running locally only ❌                       │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                    TARGET (Full Stack)                   │
│                                                           │
│  Users → CloudFront → S3 (Frontend) ──API calls──┐      │
│                                                    │      │
│                                                    ▼      │
│                              ALB → ECS (Backend) → RDS   │
└─────────────────────────────────────────────────────────┘
```

---

## 🎯 Frontend Deployment Options

### Option 1: S3 + CloudFront (Recommended) ⭐

**Best for:** Production, scalability, low cost

**Pros:**
- ✅ Cheapest ($1-5/month)
- ✅ Global CDN (fast worldwide)
- ✅ HTTPS included
- ✅ Highly scalable
- ✅ No server management

**Cons:**
- ⚠️ Static files only
- ⚠️ Requires build step

**Cost:** ~$1-5/month

---

### Option 2: Amplify Hosting

**Best for:** Quick deployment, CI/CD

**Pros:**
- ✅ Easy setup
- ✅ Built-in CI/CD
- ✅ Preview deployments
- ✅ Custom domains

**Cons:**
- ⚠️ More expensive ($15-50/month)
- ⚠️ Less control

**Cost:** ~$15-50/month

---

### Option 3: Serve from Express (Not Recommended)

**Best for:** Simple deployments, monolith

**Pros:**
- ✅ Single deployment
- ✅ Same domain

**Cons:**
- ❌ Backend serves static files (inefficient)
- ❌ No CDN benefits
- ❌ Wastes ECS resources
- ❌ Slower for users

**Cost:** Included in ECS cost

---

## 🚀 Recommended: S3 + CloudFront Deployment

### Architecture

```
User Request
    ↓
CloudFront (CDN)
    ↓
S3 Bucket (Static Files)
    ↓
React App Loads
    ↓
API Calls → ALB → ECS Backend
```

---

## 📋 Step-by-Step Deployment

### Phase 1: Prepare Frontend (10 minutes)

#### Step 1.1: Update Environment Variables

1. **Create production .env file:**
```bash
cat > .env.production << 'EOF'
# Backend API URL (your ALB endpoint)
VITE_API_BASE_URL=http://singha-loyalty-alb-xxxxx.us-east-1.elb.amazonaws.com/api

# AWS Region
VITE_AWS_REGION=us-east-1

# Environment
VITE_ENV=production
EOF
```

2. **Update with your actual ALB DNS:**
```bash
# Get your ALB DNS from backend deployment
aws cloudformation describe-stacks \
  --stack-name singha-loyalty-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`ALBEndpoint`].OutputValue' \
  --output text
```

3. **Update .env.production with the DNS:**
```env
VITE_API_BASE_URL=http://[YOUR-ALB-DNS]/api
```

---

#### Step 1.2: Build Frontend

```bash
# Install dependencies
npm install

# Build for production
npm run build

# Verify build
ls -la dist/
```

**Expected output:**
```
dist/
├── index.html
├── assets/
│   ├── index-[hash].js
│   ├── index-[hash].css
│   └── ...
└── ...
```

---

### Phase 2: Deploy to S3 (15 minutes)

#### Step 2.1: Create S3 Bucket

**Using AWS Console:**

1. Go to **S3** → **Create bucket**
2. Configure:
   ```
   Bucket name: singha-loyalty-frontend
   Region: us-east-1
   Block all public access: ☐ UNCHECK
   ```
3. Click **Create bucket**

**Using AWS CLI:**
```bash
# Create bucket
aws s3 mb s3://singha-loyalty-frontend --region us-east-1

# Configure for website hosting
aws s3 website s3://singha-loyalty-frontend \
  --index-document index.html \
  --error-document index.html
```

---

#### Step 2.2: Configure Bucket Policy

1. **Go to bucket** → **Permissions** → **Bucket Policy**
2. **Add this policy:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::singha-loyalty-frontend/*"
    }
  ]
}
```

3. **Save changes**

---

#### Step 2.3: Upload Files

**Using AWS Console:**
1. Go to bucket → **Objects** → **Upload**
2. Drag all files from `dist/` folder
3. Click **Upload**

**Using AWS CLI:**
```bash
# Upload all files
aws s3 sync dist/ s3://singha-loyalty-frontend \
  --delete \
  --cache-control "public, max-age=31536000" \
  --exclude "index.html"

# Upload index.html separately (no cache)
aws s3 cp dist/index.html s3://singha-loyalty-frontend/index.html \
  --cache-control "no-cache, no-store, must-revalidate"
```

---

#### Step 2.4: Test S3 Website

```bash
# Get website URL
aws s3api get-bucket-website \
  --bucket singha-loyalty-frontend \
  --query 'IndexDocument.Suffix' \
  --output text

# URL format:
# http://singha-loyalty-frontend.s3-website-us-east-1.amazonaws.com
```

**Open in browser and test!**

---

### Phase 3: Setup CloudFront (20 minutes)

#### Step 3.1: Create CloudFront Distribution

**Using AWS Console:**

1. Go to **CloudFront** → **Create distribution**

2. **Origin settings:**
   ```
   Origin domain: singha-loyalty-frontend.s3.us-east-1.amazonaws.com
   Origin path: (leave empty)
   Name: S3-singha-loyalty-frontend
   Origin access: Public
   ```

3. **Default cache behavior:**
   ```
   Viewer protocol policy: Redirect HTTP to HTTPS
   Allowed HTTP methods: GET, HEAD, OPTIONS
   Cache policy: CachingOptimized
   ```

4. **Settings:**
   ```
   Price class: Use only North America and Europe (cheapest)
   Alternate domain name (CNAME): (leave empty for now)
   Custom SSL certificate: Default CloudFront certificate
   Default root object: index.html
   ```

5. **Click Create distribution**

**Wait time:** 10-15 minutes for deployment

---

#### Step 3.2: Configure Error Pages

1. **Go to distribution** → **Error pages** tab
2. **Create custom error response:**
   ```
   HTTP error code: 403
   Customize error response: Yes
   Response page path: /index.html
   HTTP response code: 200
   ```
3. **Create another for 404:**
   ```
   HTTP error code: 404
   Customize error response: Yes
   Response page path: /index.html
   HTTP response code: 200
   ```

**Why?** This enables React Router to handle all routes.

---

#### Step 3.3: Get CloudFront URL

```bash
# List distributions
aws cloudfront list-distributions \
  --query 'DistributionList.Items[?Origins.Items[0].DomainName==`singha-loyalty-frontend.s3.us-east-1.amazonaws.com`].DomainName' \
  --output text
```

**URL format:** `https://d1234567890abc.cloudfront.net`

---

### Phase 4: Configure CORS (5 minutes)

Your backend needs to allow requests from CloudFront.

#### Step 4.1: Update Backend CORS

**Edit:** `server/src/index.js`

```javascript
// Before (allows all)
app.use(cors({
  origin: '*'
}));

// After (restrict to your frontend)
app.use(cors({
  origin: [
    'http://localhost:8080',  // Local development
    'http://localhost:5173',  // Vite dev server
    'https://d1234567890abc.cloudfront.net',  // Your CloudFront URL
    'https://yourdomain.com'  // Your custom domain (if any)
  ],
  credentials: true
}));
```

#### Step 4.2: Redeploy Backend

```bash
cd server

# Rebuild Docker image
docker build -t singha-loyalty:latest .

# Push to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin [YOUR-ECR-URI]

docker tag singha-loyalty:latest [YOUR-ECR-URI]:latest
docker push [YOUR-ECR-URI]:latest

# Force ECS to use new image
aws ecs update-service \
  --cluster singha-loyalty-cluster \
  --service singha-loyalty-service \
  --force-new-deployment \
  --region us-east-1
```

---

### Phase 5: Test Complete System (10 minutes)

#### Test Checklist

1. **Open CloudFront URL** in browser
   ```
   https://d1234567890abc.cloudfront.net
   ```

2. **Test customer registration:**
   - Fill in form
   - Submit
   - Verify success message
   - Check loyalty number displayed

3. **Test admin login:**
   - Navigate to `/admin`
   - Enter credentials
   - Verify dashboard loads
   - Check customer list displays

4. **Test API calls:**
   - Open browser DevTools → Network tab
   - Verify API calls go to your ALB
   - Check for CORS errors (should be none)

5. **Test routing:**
   - Navigate to different pages
   - Refresh page (should not 404)
   - Use browser back/forward

---

## 🔄 Automated Deployment Script

Create a deployment script for easy updates:

```bash
cat > deploy-frontend.sh << 'EOF'
#!/bin/bash

set -e

echo "🚀 Deploying Frontend to AWS..."

# Configuration
BUCKET_NAME="singha-loyalty-frontend"
DISTRIBUTION_ID="[YOUR-CLOUDFRONT-ID]"

# Build
echo "📦 Building frontend..."
npm run build

# Upload to S3
echo "⬆️  Uploading to S3..."
aws s3 sync dist/ s3://$BUCKET_NAME \
  --delete \
  --cache-control "public, max-age=31536000" \
  --exclude "index.html"

aws s3 cp dist/index.html s3://$BUCKET_NAME/index.html \
  --cache-control "no-cache, no-store, must-revalidate"

# Invalidate CloudFront cache
echo "🔄 Invalidating CloudFront cache..."
aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/*"

echo "✅ Deployment complete!"
echo "🌐 URL: https://[YOUR-CLOUDFRONT-URL]"
EOF

chmod +x deploy-frontend.sh
```

**Usage:**
```bash
./deploy-frontend.sh
```

---

## 💰 Cost Breakdown

### S3 + CloudFront (Recommended)

| Service | Usage | Cost |
|---------|-------|------|
| **S3 Storage** | ~50MB | $0.01/month |
| **S3 Requests** | 10k requests | $0.01/month |
| **CloudFront** | 10GB transfer | $1.00/month |
| **CloudFront Requests** | 10k requests | $0.01/month |
| **Total** | | **~$1-5/month** |

### Complete System Cost

```
Backend (ECS + RDS + ALB):  $45-62/month
Frontend (S3 + CloudFront):  $1-5/month
─────────────────────────────────────────
Total:                       $46-67/month
```

---

## 🎯 Optional: Custom Domain (Bonus)

### Step 1: Register Domain (Route 53)

```bash
# Check if domain is available
aws route53domains check-domain-availability \
  --domain-name singhaloyalty.com

# Register domain (costs $12/year)
aws route53domains register-domain \
  --domain-name singhaloyalty.com \
  --duration-in-years 1 \
  --admin-contact file://contact.json \
  --registrant-contact file://contact.json \
  --tech-contact file://contact.json
```

### Step 2: Request SSL Certificate (ACM)

1. Go to **ACM** (us-east-1 region - required for CloudFront)
2. **Request certificate**
3. **Domain names:**
   ```
   singhaloyalty.com
   www.singhaloyalty.com
   ```
4. **Validation:** DNS validation
5. **Add CNAME records** to Route 53
6. **Wait for validation** (~5-30 minutes)

### Step 3: Update CloudFront

1. Go to **CloudFront** → Your distribution → **Edit**
2. **Alternate domain names (CNAMEs):**
   ```
   singhaloyalty.com
   www.singhaloyalty.com
   ```
3. **Custom SSL certificate:** Select your ACM certificate
4. **Save changes**

### Step 4: Create Route 53 Records

```bash
# Get CloudFront domain
CLOUDFRONT_DOMAIN="d1234567890abc.cloudfront.net"

# Create A record
aws route53 change-resource-record-sets \
  --hosted-zone-id [YOUR-ZONE-ID] \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "singhaloyalty.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z2FDTNDATAQYW2",
          "DNSName": "'$CLOUDFRONT_DOMAIN'",
          "EvaluateTargetHealth": false
        }
      }
    }]
  }'
```

**Now accessible at:** `https://singhaloyalty.com` 🎉

---

## 🔄 CI/CD for Frontend

### GitHub Actions Workflow

Create `.github/workflows/deploy-frontend.yml`:

```yaml
name: Deploy Frontend

on:
  push:
    branches: [ main ]
    paths:
      - 'src/**'
      - 'public/**'
      - 'index.html'
      - 'package.json'

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Build
        run: npm run build
        env:
          VITE_API_BASE_URL: ${{ secrets.API_BASE_URL }}
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Deploy to S3
        run: |
          aws s3 sync dist/ s3://singha-loyalty-frontend \
            --delete \
            --cache-control "public, max-age=31536000" \
            --exclude "index.html"
          
          aws s3 cp dist/index.html s3://singha-loyalty-frontend/index.html \
            --cache-control "no-cache, no-store, must-revalidate"
      
      - name: Invalidate CloudFront
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID }} \
            --paths "/*"
```

**Setup secrets in GitHub:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `API_BASE_URL`
- `CLOUDFRONT_DISTRIBUTION_ID`

---

## 🧪 Testing Checklist

### Before Deployment
- [ ] Build succeeds locally
- [ ] All environment variables set
- [ ] API URL points to backend
- [ ] No console errors

### After Deployment
- [ ] CloudFront URL loads
- [ ] All pages accessible
- [ ] API calls work
- [ ] No CORS errors
- [ ] Images load
- [ ] Routing works
- [ ] Refresh doesn't 404

### Performance
- [ ] Lighthouse score > 90
- [ ] First contentful paint < 2s
- [ ] Time to interactive < 3s
- [ ] No render-blocking resources

---

## 🐛 Troubleshooting

### Issue: White screen / blank page

**Cause:** Build path issues

**Fix:**
```javascript
// vite.config.ts
export default defineConfig({
  base: '/',  // Ensure this is set
  // ...
});
```

### Issue: 403 Forbidden

**Cause:** S3 bucket policy not set

**Fix:** Add bucket policy (see Step 2.2)

### Issue: CORS errors

**Cause:** Backend not allowing CloudFront origin

**Fix:** Update CORS in backend (see Phase 4)

### Issue: 404 on refresh

**Cause:** CloudFront error pages not configured

**Fix:** Add error page redirects (see Step 3.2)

### Issue: Old version showing

**Cause:** CloudFront cache

**Fix:**
```bash
aws cloudfront create-invalidation \
  --distribution-id [YOUR-ID] \
  --paths "/*"
```

---

## 📊 Complete Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                         USERS                                 │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │   Route 53 (Optional)│
              │   singhaloyalty.com  │
              └──────────┬───────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │     CloudFront       │
              │     (Global CDN)     │
              │     HTTPS            │
              └──────────┬───────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │     S3 Bucket        │
              │  (Static Frontend)   │
              │  - index.html        │
              │  - JS bundles        │
              │  - CSS files         │
              └──────────────────────┘
                         │
                         │ API Calls
                         ▼
              ┌──────────────────────┐
              │         ALB          │
              └──────────┬───────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │    ECS Fargate       │
              │  (Backend API)       │
              └──────────┬───────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │     RDS MySQL        │
              │    (Database)        │
              └──────────────────────┘
```

---

## ✅ Deployment Complete!

### What You Have Now:

✅ **Backend:** ECS Fargate + RDS (deployed)
✅ **Frontend:** S3 + CloudFront (deployed)
✅ **HTTPS:** CloudFront SSL
✅ **Global CDN:** Fast worldwide
✅ **Scalable:** Handles traffic spikes
✅ **Cost-effective:** ~$50-70/month total

### Access Your Application:

**Frontend:** `https://[your-cloudfront-url]`
**Backend API:** `http://[your-alb-dns]/api`

### Next Steps:

1. [ ] Add custom domain (optional)
2. [ ] Setup CI/CD for frontend
3. [ ] Configure monitoring
4. [ ] Add analytics
5. [ ] Optimize performance

---

**Questions?** See troubleshooting section or contact DevOps team.

**Congratulations! Your full-stack application is now live on AWS! 🎉**
