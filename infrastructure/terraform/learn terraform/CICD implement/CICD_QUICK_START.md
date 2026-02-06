# CI/CD Pipeline - Quick Start Guide

Get your automated deployment pipeline running in 10 minutes!

## 🚀 Quick Setup (3 Steps)

### Step 1: Create GitHub Connection (2 minutes)

1. Open: https://console.aws.amazon.com/codesuite/settings/connections
2. Click **"Create connection"**
3. Choose **"GitHub"** → Name it `github-connection`
4. Click **"Connect to GitHub"** → **"Authorize"**
5. **Copy the ARN** (looks like: `arn:aws:codestar-connections:us-east-1:...`)

### Step 2: Configure Terraform (3 minutes)

Create `infrastructure/terraform/terraform.tfvars`:

```hcl
# Basic settings
aws_region   = "us-east-1"
project_name = "singha-loyalty"
environment  = "production"

# Database (change these!)
db_username = "admin"
db_password = "YourSecurePassword123!"

# JWT secret (change this!)
jwt_secret = "your-super-secret-jwt-key-min-32-chars-long"

# Enable CI/CD
enable_cicd_pipeline = true

# GitHub settings (update these!)
github_connection_arn = "arn:aws:codestar-connections:us-east-1:285229572166:connection/xxxxx"
github_repository     = "yourusername/singhasuper-containerized"
github_branch         = "main"
```

### Step 3: Deploy (5 minutes)

```bash
cd infrastructure/terraform

# Initialize
terraform init

# Deploy
terraform apply
# Type 'yes' when prompted
```

## ✅ Done!

Your pipeline is ready! Now every `git push` will automatically:
1. Build your Docker image
2. Push to ECR
3. Deploy to ECS with zero downtime

## 🧪 Test It

```bash
# Make a change
echo "# Test" >> README.md

# Push
git add .
git commit -m "Test pipeline"
git push origin main

# Watch it deploy
# Go to: https://console.aws.amazon.com/codesuite/codepipeline/pipelines
```

## 📊 Monitor

**View Pipeline:**
```bash
terraform output pipeline_name
# Then go to AWS Console → CodePipeline
```

**View Build Logs:**
```bash
aws logs tail /aws/codebuild/singha-loyalty-build --follow
```

## 🔧 Troubleshooting

**Pipeline not triggering?**
- Check GitHub connection status is "AVAILABLE"
- Verify webhook exists in GitHub repo settings

**Build failing?**
- Check CloudWatch logs: `/aws/codebuild/singha-loyalty-build`
- Verify buildspec.yml path is correct

**Deploy failing?**
- Check ECS service events
- Verify task definition is valid

## 💰 Cost

**~$2.87/month** for 50 builds
- $1.00 CodePipeline
- $1.25 CodeBuild
- $0.62 S3 + Logs

## 📚 Full Documentation

See `CICD_SETUP_GUIDE.md` for detailed instructions.

---

**That's it! Your CI/CD pipeline is automated with Terraform! 🎉**
