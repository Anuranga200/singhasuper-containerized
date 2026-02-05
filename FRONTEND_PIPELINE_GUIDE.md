# Frontend CI/CD Pipeline Guide

## 🎯 Overview

This guide sets up a **complete CI/CD pipeline** for your React frontend using AWS services:

```
GitHub Push → CodePipeline → CodeBuild → S3 → CloudFront
```

**What it does:**
1. Monitors your GitHub repository
2. Automatically builds React app on code push
3. Deploys to S3
4. Invalidates CloudFront cache
5. Makes new version live

**Cost:** ~$2-7/month (includes S3, CloudFront, and pipeline)

---

## 📊 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    CI/CD Pipeline                            │
│                                                               │
│  Developer                                                    │
│      │                                                        │
│      │ git push                                              │
│      ▼                                                        │
│  ┌──────────┐                                                │
│  │  GitHub  │                                                │
│  └────┬─────┘                                                │
│       │ webhook                                              │
│       ▼                                                        │
│  ┌──────────────┐                                            │
│  │ CodePipeline │                                            │
│  │  (Orchestrate)│                                           │
│  └────┬─────────┘                                            │
│       │                                                        │
│       ▼                                                        │
│  ┌──────────────┐                                            │
│  │  CodeBuild   │                                            │
│  │  - npm ci    │                                            │
│  │  - npm build │                                            │
│  │  - aws s3 sync│                                           │
│  └────┬─────────┘                                            │
│       │                                                        │
│       ▼                                                        │
│  ┌──────────────┐      ┌──────────────┐                     │
│  │  S3 Bucket   │─────▶│  CloudFront  │                     │
│  │ (Static Files)│      │    (CDN)     │                     │
│  └──────────────┘      └──────┬───────┘                     │
│                                │                              │
│                                ▼                              │
│                            Users                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start (10 minutes)

### Prerequisites

- [ ] AWS account configured
- [ ] GitHub repository with your code
- [ ] GitHub Personal Access Token
- [ ] Backend already deployed (for API URL)

### Step 1: Create GitHub Token

1. Go to https://github.com/settings/tokens
2. Click **Generate new token (classic)**
3. Select scopes:
   - ✅ `repo` (Full control of private repositories)
   - ✅ `admin:repo_hook` (Full control of repository hooks)
4. Click **Generate token**
5. **Copy the token** (you won't see it again!)

---

### Step 2: Deploy Pipeline

```bash
# Make script executable
chmod +x infrastructure/deploy-frontend-pipeline.sh

# Run deployment
./infrastructure/deploy-frontend-pipeline.sh
```

**You'll be prompted for:**
- GitHub repository (e.g., `username/singha-loyalty`)
- GitHub branch (default: `main`)
- GitHub token (paste the token you created)
- Backend API URL (auto-detected if backend is deployed)
- S3 bucket name (default: `singha-loyalty-frontend`)

**Wait time:** 5-10 minutes

---

### Step 3: Monitor Pipeline

The script will output a pipeline URL. Open it to watch the deployment:

```
Pipeline URL: https://console.aws.amazon.com/codesuite/codepipeline/pipelines/singha-loyalty-frontend-pipeline/view
```

**Pipeline stages:**
1. **Source** - Pulls code from GitHub (30 seconds)
2. **BuildAndDeploy** - Builds and deploys (3-5 minutes)

**Wait for:** ✅ All stages green

---

### Step 4: Access Your Frontend

```
Frontend URL: https://d1234567890abc.cloudfront.net
```

**Note:** CloudFront may take 10-15 minutes to fully deploy globally.

---

## 📋 What Gets Created

### AWS Resources

| Resource | Purpose | Cost |
|----------|---------|------|
| **S3 Bucket** | Hosts static files | $0.01/month |
| **CloudFront** | Global CDN | $1-5/month |
| **CodePipeline** | Orchestrates CI/CD | $1/month |
| **CodeBuild** | Builds React app | $0.01/minute |
| **Artifact Bucket** | Stores build artifacts | $0.01/month |
| **IAM Roles** | Permissions | Free |
| **CloudWatch Logs** | Build logs | Free tier |

**Total:** ~$2-7/month

---

### Pipeline Configuration

**Buildspec (what CodeBuild does):**
```yaml
phases:
  pre_build:
    - npm ci  # Install dependencies
  
  build:
    - npm run build  # Build React app
  
  post_build:
    - aws s3 sync dist/ s3://bucket  # Upload to S3
    - aws cloudfront create-invalidation  # Clear cache
```

---

## 🔄 How It Works

### Automatic Deployments

```
1. Developer makes changes
   ↓
2. git add . && git commit -m "Update"
   ↓
3. git push origin main
   ↓
4. GitHub webhook triggers CodePipeline
   ↓
5. CodePipeline starts CodeBuild
   ↓
6. CodeBuild:
   - Installs dependencies
   - Builds React app
   - Uploads to S3
   - Invalidates CloudFront
   ↓
7. New version live in 3-5 minutes!
```

---

### Manual Trigger

If you need to manually trigger the pipeline:

```bash
# Use helper script
./trigger-pipeline.sh

# Or use AWS CLI
aws codepipeline start-pipeline-execution \
  --name singha-loyalty-frontend-pipeline
```

---

## 🔧 Configuration

### Environment Variables

The pipeline automatically sets these during build:

```bash
VITE_API_BASE_URL=http://[your-alb-dns]/api
VITE_AWS_REGION=us-east-1
```

**To update:**
1. Go to CodeBuild → Projects → singha-loyalty-frontend-build
2. Click **Edit** → **Environment**
3. Update environment variables
4. Click **Update environment**

---

### Update Backend API URL

If your backend URL changes:

```bash
# Update CloudFormation stack
aws cloudformation update-stack \
  --stack-name singha-loyalty-frontend-pipeline \
  --use-previous-template \
  --parameters \
    ParameterKey=BackendAPIURL,ParameterValue=http://new-alb-dns/api \
    ParameterKey=GitHubToken,UsePreviousValue=true \
    ParameterKey=GitHubRepo,UsePreviousValue=true \
    ParameterKey=GitHubBranch,UsePreviousValue=true \
    ParameterKey=S3BucketName,UsePreviousValue=true \
  --capabilities CAPABILITY_NAMED_IAM
```

---

## 🧪 Testing

### Test Pipeline

1. **Make a small change:**
   ```bash
   # Edit a file
   echo "// Test change" >> src/App.tsx
   
   # Commit and push
   git add .
   git commit -m "Test pipeline"
   git push origin main
   ```

2. **Watch pipeline:**
   - Go to CodePipeline console
   - Watch stages progress
   - Check for errors

3. **Verify deployment:**
   - Open CloudFront URL
   - Check if change is visible
   - Check browser console for errors

---

### Test CloudFront

```bash
# Check CloudFront status
aws cloudfront get-distribution \
  --id [YOUR-DISTRIBUTION-ID] \
  --query 'Distribution.Status'

# Should return: "Deployed"
```

---

## 🐛 Troubleshooting

### Issue 1: Pipeline Fails at Source Stage

**Symptom:**
```
Failed to connect to GitHub
```

**Causes:**
- Invalid GitHub token
- Wrong repository name
- Token doesn't have required scopes

**Fix:**
1. Create new GitHub token with correct scopes
2. Update stack with new token:
   ```bash
   aws cloudformation update-stack \
     --stack-name singha-loyalty-frontend-pipeline \
     --use-previous-template \
     --parameters \
       ParameterKey=GitHubToken,ParameterValue=NEW_TOKEN \
       [other parameters with UsePreviousValue=true]
   ```

---

### Issue 2: Build Fails

**Symptom:**
```
npm ERR! code ELIFECYCLE
Build failed
```

**Causes:**
- Build errors in code
- Missing dependencies
- Environment variables not set

**Fix:**
1. Check CodeBuild logs:
   ```bash
   aws logs tail /aws/codebuild/singha-loyalty-frontend-build --follow
   ```

2. Test build locally:
   ```bash
   npm ci
   npm run build
   ```

3. Fix errors and push again

---

### Issue 3: S3 Upload Fails

**Symptom:**
```
Access Denied
Unable to sync to S3
```

**Cause:** IAM permissions issue

**Fix:**
1. Check CodeBuild role has S3 permissions
2. Verify bucket policy allows CodeBuild
3. Check bucket name is correct

---

### Issue 4: CloudFront Not Updating

**Symptom:**
- Pipeline succeeds
- Old version still showing

**Cause:** CloudFront cache not invalidated

**Fix:**
```bash
# Manual invalidation
./invalidate-cloudfront.sh

# Or use AWS CLI
aws cloudfront create-invalidation \
  --distribution-id [YOUR-ID] \
  --paths "/*"
```

---

### Issue 5: CORS Errors

**Symptom:**
```
Access to fetch at 'http://alb-dns/api' has been blocked by CORS
```

**Cause:** Backend doesn't allow CloudFront origin

**Fix:**
1. Get CloudFront URL from pipeline output
2. Update backend CORS:
   ```javascript
   // server/src/index.js
   app.use(cors({
     origin: [
       'http://localhost:8080',
       'https://[YOUR-CLOUDFRONT-URL]'  // Add this
     ]
   }));
   ```
3. Redeploy backend

---

## 📊 Monitoring

### View Pipeline Status

```bash
# Get pipeline status
aws codepipeline get-pipeline-state \
  --name singha-loyalty-frontend-pipeline

# Get latest execution
aws codepipeline list-pipeline-executions \
  --pipeline-name singha-loyalty-frontend-pipeline \
  --max-items 1
```

---

### View Build Logs

```bash
# Real-time logs
aws logs tail /aws/codebuild/singha-loyalty-frontend-build --follow

# Last 100 lines
aws logs tail /aws/codebuild/singha-loyalty-frontend-build --since 1h
```

---

### CloudFront Metrics

```bash
# Get request count
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront \
  --metric-name Requests \
  --dimensions Name=DistributionId,Value=[YOUR-ID] \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum
```

---

## 🔐 Security Best Practices

### 1. Secure GitHub Token

**Do:**
- ✅ Use GitHub token with minimal scopes
- ✅ Store token in AWS Secrets Manager (advanced)
- ✅ Rotate token regularly
- ✅ Use different tokens for different environments

**Don't:**
- ❌ Commit token to repository
- ❌ Share token with others
- ❌ Use personal token for production

---

### 2. S3 Bucket Security

**Current setup:**
- Public read access (required for website)
- No public write access
- Encryption at rest

**Improvements:**
- Use CloudFront Origin Access Identity (OAI)
- Enable S3 access logging
- Enable versioning for rollback

---

### 3. CloudFront Security

**Current setup:**
- HTTPS redirect enabled
- Compression enabled

**Improvements:**
- Add custom domain with ACM certificate
- Enable AWS WAF
- Add security headers
- Enable field-level encryption

---

## 💰 Cost Optimization

### Current Costs

```
CodePipeline:     $1/month (1 pipeline)
CodeBuild:        $0.01/minute × ~5 min/build × ~30 builds = $1.50/month
S3 Storage:       ~50MB × $0.023/GB = $0.01/month
S3 Requests:      ~1000 × $0.0004/1000 = $0.001/month
CloudFront:       10GB × $0.085/GB = $0.85/month
CloudFront Req:   10k × $0.0075/10k = $0.01/month
────────────────────────────────────────────────────
Total:            ~$3.37/month
```

### Optimization Tips

1. **Reduce build frequency:**
   - Batch commits before pushing
   - Use feature branches
   - Only build on main branch

2. **Optimize build time:**
   - Use npm ci instead of npm install
   - Enable CodeBuild caching
   - Minimize dependencies

3. **CloudFront optimization:**
   - Use Price Class 100 (cheapest)
   - Set appropriate cache TTLs
   - Enable compression

---

## 🔄 Advanced Configuration

### Multi-Environment Setup

Deploy separate pipelines for dev/staging/prod:

```bash
# Development
./infrastructure/deploy-frontend-pipeline.sh \
  --environment dev \
  --branch develop

# Staging
./infrastructure/deploy-frontend-pipeline.sh \
  --environment staging \
  --branch staging

# Production
./infrastructure/deploy-frontend-pipeline.sh \
  --environment prod \
  --branch main
```

---

### Custom Domain

1. **Register domain in Route 53**
2. **Request SSL certificate in ACM** (us-east-1 region)
3. **Update CloudFormation:**
   ```yaml
   CloudFrontDistribution:
     Properties:
       DistributionConfig:
         Aliases:
           - www.yourdomain.com
         ViewerCertificate:
           AcmCertificateArn: arn:aws:acm:...
   ```
4. **Create Route 53 A record** pointing to CloudFront

---

### Notifications

Add SNS notifications for pipeline events:

```yaml
# Add to CloudFormation
PipelineNotificationTopic:
  Type: AWS::SNS::Topic
  Properties:
    DisplayName: Pipeline Notifications
    Subscription:
      - Endpoint: your-email@example.com
        Protocol: email

PipelineEventRule:
  Type: AWS::Events::Rule
  Properties:
    EventPattern:
      source:
        - aws.codepipeline
      detail-type:
        - CodePipeline Pipeline Execution State Change
      detail:
        state:
          - FAILED
          - SUCCEEDED
    Targets:
      - Arn: !Ref PipelineNotificationTopic
        Id: PipelineNotificationTarget
```

---

## 📚 Helper Scripts

### Invalidate CloudFront Cache

```bash
./invalidate-cloudfront.sh
```

### Manually Trigger Pipeline

```bash
./trigger-pipeline.sh
```

### View Pipeline Status

```bash
#!/bin/bash
source .frontend-pipeline-config

aws codepipeline get-pipeline-state \
  --name ${PROJECT_NAME}-pipeline \
  | jq '.stageStates[] | {stage: .stageName, status: .latestExecution.status}'
```

---

## 🧹 Cleanup

### Delete Pipeline

```bash
# Delete CloudFormation stack
aws cloudformation delete-stack \
  --stack-name singha-loyalty-frontend-pipeline

# Wait for deletion
aws cloudformation wait stack-delete-complete \
  --stack-name singha-loyalty-frontend-pipeline

# Manually delete S3 buckets (if needed)
aws s3 rb s3://singha-loyalty-frontend --force
aws s3 rb s3://singha-loyalty-frontend-pipeline-artifacts-[ACCOUNT-ID] --force
```

**Note:** CloudFront distributions take 15-20 minutes to delete.

---

## ✅ Verification Checklist

### After Deployment

- [ ] Pipeline created successfully
- [ ] S3 bucket created
- [ ] CloudFront distribution deployed
- [ ] GitHub webhook configured
- [ ] Initial build succeeded
- [ ] Frontend accessible via CloudFront URL
- [ ] API calls work (no CORS errors)
- [ ] All pages load correctly
- [ ] Routing works (no 404 on refresh)

### After Code Push

- [ ] Pipeline triggered automatically
- [ ] Build succeeded
- [ ] Files uploaded to S3
- [ ] CloudFront cache invalidated
- [ ] New version visible
- [ ] No errors in browser console

---

## 🎉 Success!

You now have a fully automated CI/CD pipeline for your frontend!

**What you achieved:**
- ✅ Automatic deployments on git push
- ✅ Global CDN with CloudFront
- ✅ HTTPS enabled
- ✅ Fast builds (3-5 minutes)
- ✅ Zero-downtime deployments
- ✅ Cost-effective (~$3-7/month)

**Next steps:**
1. Push code to GitHub
2. Watch it deploy automatically
3. Access via CloudFront URL
4. Add custom domain (optional)
5. Set up monitoring alerts

---

**Questions?** Check troubleshooting section or AWS documentation.

**Congratulations! Your frontend CI/CD pipeline is live! 🚀**
