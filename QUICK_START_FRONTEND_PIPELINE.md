# 🚀 Quick Start: Frontend CI/CD Pipeline

## ✅ What's Ready

All files have been created successfully:

```
infrastructure/
├── frontend-pipeline.yaml          ✅ CloudFormation template
├── deploy-frontend-pipeline.sh     ✅ Linux/Mac deployment script
├── deploy-frontend-pipeline.bat    ✅ Windows deployment script
└── buildspec-frontend.yml          ✅ CodeBuild configuration

Documentation/
├── FRONTEND_PIPELINE_GUIDE.md      ✅ Complete guide
├── FRONTEND_DEPLOYMENT_GUIDE.md    ✅ Manual S3+CloudFront guide
└── FULL_STACK_DEPLOYMENT.md        ✅ Full stack overview
```

---

## 🎯 What This Pipeline Does

```
Your Code → GitHub → CodePipeline → CodeBuild → S3 → CloudFront → Users
```

**Automatic deployment on every git push!**

---

## 📋 Prerequisites (5 minutes)

### 1. GitHub Personal Access Token

**Create token:**
1. Go to: https://github.com/settings/tokens
2. Click: **Generate new token (classic)**
3. Select scopes:
   - ✅ `repo` (Full control of private repositories)
   - ✅ `admin:repo_hook` (Full control of repository hooks)
4. Click: **Generate token**
5. **Copy the token** (save it somewhere safe!)

### 2. Backend API URL

You need your backend ALB URL. Get it from:

**Option A - From CloudFormation:**
```cmd
aws cloudformation describe-stacks ^
  --stack-name singha-loyalty-stack ^
  --query "Stacks[0].Outputs[?OutputKey=='ALBEndpoint'].OutputValue" ^
  --output text
```

**Option B - From ECS Console:**
1. Go to: EC2 → Load Balancers
2. Find: `singha-loyalty-alb`
3. Copy: DNS name
4. Format: `http://[DNS-name]/api`

**Example:** `http://singha-loyalty-alb-123456789.us-east-1.elb.amazonaws.com/api`

---

## 🚀 Deploy Pipeline (10 minutes)

### Windows (Your System)

```cmd
infrastructure\deploy-frontend-pipeline.bat
```

### Linux/Mac

```bash
chmod +x infrastructure/deploy-frontend-pipeline.sh
./infrastructure/deploy-frontend-pipeline.sh
```

---

## 📝 What You'll Be Asked

The script will prompt you for:

1. **GitHub repository**
   - Format: `username/repository-name`
   - Example: `john/singha-loyalty`

2. **GitHub branch**
   - Default: `main`
   - Press Enter to use default

3. **GitHub token**
   - Paste the token you created
   - It won't be visible when you type (security)

4. **Backend API URL**
   - Auto-detected if backend is deployed
   - Or enter manually

5. **S3 bucket name**
   - Default: `singha-loyalty-frontend`
   - Must be globally unique
   - If taken, try: `singha-loyalty-frontend-[your-name]`

6. **Confirm deployment**
   - Type `y` and press Enter

---

## ⏱️ Deployment Timeline

```
0:00  - Script starts
0:30  - CloudFormation stack creation begins
5:00  - Stack created (S3, CloudFront, CodePipeline, CodeBuild)
5:30  - Initial pipeline run triggered
8:00  - Build completes
8:30  - Files uploaded to S3
9:00  - CloudFront cache invalidated
10:00 - ✅ Deployment complete!
```

**Total time:** ~10 minutes

---

## 🎉 After Deployment

### You'll Get These URLs:

1. **Frontend URL** (CloudFront)
   ```
   https://d1234567890abc.cloudfront.net
   ```
   - This is your live frontend
   - Share this with users
   - HTTPS enabled automatically

2. **Pipeline URL** (CodePipeline Console)
   ```
   https://console.aws.amazon.com/codesuite/codepipeline/pipelines/...
   ```
   - Monitor deployments here
   - See build logs
   - Check for errors

### Helper Scripts Created:

```cmd
REM Clear CloudFront cache manually
invalidate-cloudfront.bat

REM Trigger pipeline manually
trigger-pipeline.bat
```

---

## 🔄 How to Deploy Updates

### Automatic (Recommended)

```bash
# Make your changes
git add .
git commit -m "Update feature"
git push origin main

# Pipeline automatically:
# 1. Detects push (30 seconds)
# 2. Builds React app (3-5 minutes)
# 3. Deploys to S3
# 4. Clears CloudFront cache
# 5. New version live!
```

**Total time:** 3-5 minutes per deployment

### Manual Trigger

```cmd
trigger-pipeline.bat
```

---

## ✅ Verification Steps

### 1. Check Pipeline Status

Open the Pipeline URL from deployment output:
- ✅ Source stage: Green
- ✅ BuildAndDeploy stage: Green

### 2. Test Frontend

Open the CloudFront URL:
- ✅ Page loads
- ✅ No errors in browser console (F12)
- ✅ Can navigate between pages
- ✅ API calls work

### 3. Test Registration

1. Go to: `/register`
2. Fill form
3. Submit
4. Check if it works

**If you get CORS errors:**
- See "Fix CORS" section below

---

## 🐛 Common Issues & Fixes

### Issue 1: CORS Errors

**Symptom:**
```
Access to fetch at 'http://alb-dns/api' has been blocked by CORS
```

**Fix:**
1. Get your CloudFront URL from deployment output
2. Update backend CORS:

```javascript
// server/src/index.js
app.use(cors({
  origin: [
    'http://localhost:8080',
    'https://d1234567890abc.cloudfront.net'  // Add your CloudFront URL
  ],
  credentials: true
}));
```

3. Redeploy backend:
```cmd
cd server
docker build -t singha-loyalty-backend .
docker tag singha-loyalty-backend:latest [ECR-URL]:latest
docker push [ECR-URL]:latest
```

4. Restart ECS service (it will auto-update)

---

### Issue 2: S3 Bucket Name Taken

**Symptom:**
```
Bucket name already exists
```

**Fix:**
- S3 bucket names must be globally unique
- Try: `singha-loyalty-frontend-[your-name]`
- Or: `singha-loyalty-frontend-[random-number]`

---

### Issue 3: GitHub Token Invalid

**Symptom:**
```
Failed to connect to GitHub
```

**Fix:**
1. Create new token with correct scopes
2. Update stack:
```cmd
aws cloudformation update-stack ^
  --stack-name singha-loyalty-frontend-pipeline ^
  --use-previous-template ^
  --parameters ^
    ParameterKey=GitHubToken,ParameterValue=NEW_TOKEN ^
    ParameterKey=GitHubRepo,UsePreviousValue=true ^
    ParameterKey=GitHubBranch,UsePreviousValue=true ^
    ParameterKey=S3BucketName,UsePreviousValue=true ^
    ParameterKey=BackendAPIURL,UsePreviousValue=true ^
  --capabilities CAPABILITY_NAMED_IAM
```

---

### Issue 4: Build Fails

**Symptom:**
```
Build failed in CodeBuild
```

**Fix:**
1. Check build logs in CodePipeline console
2. Test build locally:
```cmd
npm ci
npm run build
```
3. Fix errors
4. Push again

---

### Issue 5: Old Version Still Showing

**Symptom:**
- Pipeline succeeds
- But old version still visible

**Fix:**
```cmd
REM Clear CloudFront cache
invalidate-cloudfront.bat

REM Wait 2-3 minutes
REM Then refresh browser (Ctrl+F5)
```

---

## 💰 Cost Breakdown

```
Service              Cost/Month    Details
─────────────────────────────────────────────────
CodePipeline         $1.00         1 active pipeline
CodeBuild            $1.50         ~30 builds × 5 min
S3 Storage           $0.01         ~50MB static files
S3 Requests          $0.001        ~1000 requests
CloudFront           $0.85         10GB transfer
CloudFront Requests  $0.01         10k requests
─────────────────────────────────────────────────
TOTAL                ~$3.37/month
```

**Free tier eligible:** First 12 months may be free/cheaper

---

## 📊 Monitoring

### View Pipeline Status

```cmd
aws codepipeline get-pipeline-state ^
  --name singha-loyalty-frontend-pipeline
```

### View Build Logs

```cmd
aws logs tail /aws/codebuild/singha-loyalty-frontend-build --follow
```

### CloudFront Metrics

Go to: CloudFront Console → Your Distribution → Monitoring

---

## 🔐 Security Notes

### What's Secure:

- ✅ HTTPS enabled (CloudFront)
- ✅ GitHub token encrypted in CloudFormation
- ✅ IAM roles with minimal permissions
- ✅ S3 bucket encryption
- ✅ No public write access

### What to Improve:

- Add custom domain with SSL certificate
- Enable AWS WAF for DDoS protection
- Add CloudWatch alarms
- Enable S3 access logging
- Use CloudFront Origin Access Identity

---

## 🧹 Cleanup (If Needed)

### Delete Everything

```cmd
REM Delete CloudFormation stack
aws cloudformation delete-stack ^
  --stack-name singha-loyalty-frontend-pipeline

REM Wait for deletion
aws cloudformation wait stack-delete-complete ^
  --stack-name singha-loyalty-frontend-pipeline

REM Manually delete S3 buckets (if needed)
aws s3 rb s3://singha-loyalty-frontend --force
aws s3 rb s3://singha-loyalty-frontend-pipeline-artifacts-[ACCOUNT-ID] --force
```

**Note:** CloudFront takes 15-20 minutes to delete

---

## 📚 Documentation

- **Complete Guide:** `FRONTEND_PIPELINE_GUIDE.md`
- **Manual Deployment:** `FRONTEND_DEPLOYMENT_GUIDE.md`
- **Full Stack Overview:** `FULL_STACK_DEPLOYMENT.md`
- **Troubleshooting:** See FRONTEND_PIPELINE_GUIDE.md

---

## 🎯 Next Steps

1. **Deploy the pipeline:**
   ```cmd
   infrastructure\deploy-frontend-pipeline.bat
   ```

2. **Wait for completion** (~10 minutes)

3. **Test frontend** at CloudFront URL

4. **Fix CORS** if needed

5. **Make a change** and push to GitHub

6. **Watch automatic deployment** 🎉

---

## ✅ Success Checklist

- [ ] GitHub token created
- [ ] Backend API URL obtained
- [ ] Pipeline deployed successfully
- [ ] Frontend accessible via CloudFront
- [ ] No CORS errors
- [ ] Registration works
- [ ] Admin login works
- [ ] Automatic deployment tested

---

## 🆘 Need Help?

### Check These First:

1. **Pipeline Console:** See build logs and errors
2. **Browser Console (F12):** Check for JavaScript errors
3. **CloudWatch Logs:** Detailed build logs
4. **FRONTEND_PIPELINE_GUIDE.md:** Complete troubleshooting guide

### Common Commands:

```cmd
REM Check AWS credentials
aws sts get-caller-identity

REM Check stack status
aws cloudformation describe-stacks --stack-name singha-loyalty-frontend-pipeline

REM View pipeline status
aws codepipeline get-pipeline-state --name singha-loyalty-frontend-pipeline

REM Trigger pipeline
trigger-pipeline.bat

REM Clear cache
invalidate-cloudfront.bat
```

---

## 🎉 You're Ready!

Everything is set up and ready to deploy. Just run:

```cmd
infrastructure\deploy-frontend-pipeline.bat
```

**Good luck! 🚀**
