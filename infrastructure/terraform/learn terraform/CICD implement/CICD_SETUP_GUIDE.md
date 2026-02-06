# CI/CD Pipeline Setup with Terraform

This guide walks you through setting up a complete CI/CD pipeline using Terraform for the Singha Loyalty System.

## 🎯 Overview

The CI/CD pipeline automates:
- **Building** Docker images from your code
- **Pushing** images to Amazon ECR
- **Deploying** to ECS with zero downtime
- **Triggering** automatically on git push

## 📋 Prerequisites

Before starting, ensure you have:
- [x] AWS CLI configured with credentials
- [x] Terraform installed (v1.0+)
- [x] GitHub repository with your code
- [x] Existing infrastructure deployed (VPC, ECS, RDS, etc.)

---

## 🚀 Step-by-Step Setup

### Step 1: Create GitHub Connection (One-Time Setup)

The GitHub connection allows AWS to access your repository and set up webhooks automatically.

**Option A: Using AWS Console (Recommended)**

1. Go to AWS Console: https://console.aws.amazon.com/codesuite/settings/connections
2. Click **"Create connection"**
3. Select **"GitHub"**
4. Configure:
   ```
   Connection name: github-connection
   ```
5. Click **"Connect to GitHub"**
6. Click **"Authorize AWS Connector for GitHub"**
7. Select your repositories (or all repositories)
8. Click **"Connect"**
9. **Copy the Connection ARN** - it looks like:
   ```
   arn:aws:codestar-connections:us-east-1:285229572166:connection/xxxxx-xxxx-xxxx
   ```

**Option B: Using AWS CLI**

```bash
# Create the connection
aws codestar-connections create-connection \
  --provider-type GitHub \
  --connection-name github-connection \
  --region us-east-1

# Note the ConnectionArn from the output
# Then complete the handshake in the console
```

---

### Step 2: Update terraform.tfvars

Create or update `infrastructure/terraform/terraform.tfvars`:

```hcl
# ==================== Required Variables ====================
aws_region   = "us-east-1"
project_name = "singha-loyalty"
environment  = "production"

# Database credentials
db_username = "admin"
db_password = "YourSecurePassword123!"  # Change this!

# JWT secrets
jwt_secret = "your-super-secret-jwt-key-min-32-chars-long"  # Change this!

# ==================== CI/CD Pipeline Configuration ====================
enable_cicd_pipeline = true

# GitHub connection ARN (from Step 1)
github_connection_arn = "arn:aws:codestar-connections:us-east-1:285229572166:connection/xxxxx-xxxx-xxxx"

# Your GitHub repository
github_repository = "yourusername/singhasuper-containerized"

# Branch to monitor
github_branch = "main"

# ==================== Optional: CodeBuild Configuration ====================
# Compute type for builds (SMALL = 3GB RAM, MEDIUM = 7GB RAM, LARGE = 15GB RAM)
codebuild_compute_type = "BUILD_GENERAL1_SMALL"

# CodeBuild image
codebuild_image = "aws/codebuild/standard:7.0"

# Path to buildspec file
buildspec_path = "infrastructure/buildspec.yml"
```

**Important:** Replace these values:
- `github_connection_arn`: Your connection ARN from Step 1
- `github_repository`: Your GitHub username/repo
- `db_password`: A strong password
- `jwt_secret`: A random 32+ character string

---

### Step 3: Initialize Terraform

```bash
cd infrastructure/terraform

# Initialize Terraform (downloads providers)
terraform init

# Validate configuration
terraform validate
```

Expected output:
```
Success! The configuration is valid.
```

---

### Step 4: Plan the Deployment

```bash
# See what will be created
terraform plan
```

Review the plan. You should see resources being created:
- S3 bucket for artifacts
- IAM roles for CodeBuild and CodePipeline
- CodeBuild project
- CodePipeline with 3 stages
- CloudWatch log groups

---

### Step 5: Deploy the Pipeline

```bash
# Apply the configuration
terraform apply

# Type 'yes' when prompted
```

This will create:
- ✅ S3 bucket: `singha-loyalty-pipeline-artifacts-ACCOUNT_ID`
- ✅ CodeBuild project: `singha-loyalty-build`
- ✅ CodePipeline: `singha-loyalty-pipeline`
- ✅ IAM roles and policies
- ✅ CloudWatch log groups

**Wait time:** 2-3 minutes

---

### Step 6: Verify Pipeline Creation

**Check Pipeline Status:**

```bash
# List pipelines
aws codepipeline list-pipelines --region us-east-1

# Get pipeline details
aws codepipeline get-pipeline-state \
  --name singha-loyalty-pipeline \
  --region us-east-1
```

**Or use AWS Console:**
1. Go to: https://console.aws.amazon.com/codesuite/codepipeline/pipelines
2. You should see: `singha-loyalty-pipeline`
3. Click on it to view details

---

### Step 7: Test the Pipeline

The pipeline will automatically trigger when you push code. Let's test it:

```bash
# Make a small change
echo "# CI/CD Test" >> README.md

# Commit and push
git add README.md
git commit -m "Test CI/CD pipeline"
git push origin main
```

**Monitor the pipeline:**
1. Go to CodePipeline console
2. Watch the pipeline execute through 3 stages:
   - **Source** (30 seconds): Pulls code from GitHub
   - **Build** (3-5 minutes): Builds Docker image
   - **Deploy** (5-10 minutes): Updates ECS service

---

## 📊 Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Repository                         │
│                  (Your Source Code)                          │
└────────────────────┬────────────────────────────────────────┘
                     │ Git Push
                     │ (Webhook automatically created)
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              CodePipeline: Source Stage                      │
│              - Pulls latest code                             │
│              - Creates source artifact                       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              CodeBuild: Build Stage                          │
│              - Builds Docker image                           │
│              - Pushes to ECR                                 │
│              - Creates imagedefinitions.json                 │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              ECS: Deploy Stage                               │
│              - Updates ECS service                           │
│              - Rolling deployment (zero downtime)            │
│              - Health checks                                 │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔍 Monitoring & Troubleshooting

### View Build Logs

**Using AWS Console:**
1. Go to CodeBuild console
2. Click on `singha-loyalty-build`
3. Click on a build
4. View logs in real-time

**Using AWS CLI:**
```bash
# Get latest build
aws codebuild list-builds-for-project \
  --project-name singha-loyalty-build \
  --region us-east-1

# View build logs
aws logs tail /aws/codebuild/singha-loyalty-build --follow
```

### View Pipeline Execution

```bash
# Get pipeline execution history
aws codepipeline list-pipeline-executions \
  --pipeline-name singha-loyalty-pipeline \
  --region us-east-1

# Get execution details
aws codepipeline get-pipeline-execution \
  --pipeline-name singha-loyalty-pipeline \
  --pipeline-execution-id <execution-id> \
  --region us-east-1
```

### Common Issues

#### Issue 1: Pipeline Fails at Source Stage

**Symptom:** "Could not access GitHub repository"

**Solution:**
1. Check GitHub connection status:
   ```bash
   aws codestar-connections get-connection \
     --connection-arn <your-connection-arn>
   ```
2. Status should be "AVAILABLE"
3. If "PENDING", complete authorization in console

#### Issue 2: Build Fails

**Symptom:** CodeBuild stage shows red X

**Solution:**
1. Check build logs in CloudWatch
2. Common causes:
   - Buildspec file not found → Check path
   - Docker build errors → Test locally
   - ECR permissions → Check IAM role

#### Issue 3: Deploy Fails

**Symptom:** ECS deploy stage fails

**Solution:**
1. Check ECS service events
2. Verify imagedefinitions.json format
3. Check task definition is valid

---

## 🎛️ Pipeline Configuration

### Adjust Build Resources

If builds are slow or failing due to memory:

```hcl
# In terraform.tfvars
codebuild_compute_type = "BUILD_GENERAL1_MEDIUM"  # 7GB RAM
```

Compute types:
- `BUILD_GENERAL1_SMALL`: 3GB RAM, 2 vCPUs (~$0.005/min)
- `BUILD_GENERAL1_MEDIUM`: 7GB RAM, 4 vCPUs (~$0.01/min)
- `BUILD_GENERAL1_LARGE`: 15GB RAM, 8 vCPUs (~$0.02/min)

### Change Monitored Branch

```hcl
# In terraform.tfvars
github_branch = "develop"  # Monitor develop branch instead
```

### Disable Pipeline

```hcl
# In terraform.tfvars
enable_cicd_pipeline = false
```

Then run:
```bash
terraform apply
```

---

## 💰 Cost Estimation

### CI/CD Pipeline Costs

**Monthly costs (assuming 50 builds/month):**

| Service | Usage | Cost |
|---------|-------|------|
| CodePipeline | 1 active pipeline | $1.00 |
| CodeBuild | 50 builds × 5 min × SMALL | $1.25 |
| S3 (artifacts) | 5GB storage | $0.12 |
| CloudWatch Logs | 1GB logs | $0.50 |
| **Total** | | **~$2.87/month** |

**Per build cost:** ~$0.025 (2.5 cents)

### Cost Optimization Tips

1. **Use build caching:**
   - Already enabled in buildspec.yml
   - Reduces build time by 30-50%

2. **Adjust log retention:**
   ```hcl
   log_retention_days = 3  # Instead of 7
   ```

3. **Use smaller compute type:**
   - SMALL is sufficient for most builds
   - Only use MEDIUM/LARGE if needed

---

## 🔐 Security Best Practices

### 1. Secure Secrets

**Never commit secrets to git!**

Use AWS Secrets Manager or Parameter Store:

```bash
# Store DB password in Secrets Manager
aws secretsmanager create-secret \
  --name singha-loyalty/db-password \
  --secret-string "YourSecurePassword123!"

# Store JWT secret
aws secretsmanager create-secret \
  --name singha-loyalty/jwt-secret \
  --secret-string "your-super-secret-jwt-key"
```

Then update task definition to use secrets.

### 2. Restrict IAM Permissions

The Terraform module follows least-privilege:
- CodeBuild can only access ECR and S3
- CodePipeline can only update specific ECS service
- No wildcard permissions

### 3. Enable Build Artifact Encryption

Already enabled by default in the module.

### 4. Review GitHub Permissions

Limit GitHub App access to specific repositories only.

---

## 🧪 Testing the Pipeline

### Manual Trigger

```bash
# Trigger pipeline manually
aws codepipeline start-pipeline-execution \
  --name singha-loyalty-pipeline \
  --region us-east-1
```

### Test Build Locally

Before pushing, test the build locally:

```bash
cd server

# Build Docker image
docker build -t test-build .

# Run container
docker run -p 3000:3000 test-build
```

### Validate Buildspec

```bash
# Validate buildspec syntax
aws codebuild batch-get-projects \
  --names singha-loyalty-build \
  --region us-east-1
```

---

## 📚 Terraform Commands Reference

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt

# Plan changes
terraform plan

# Apply changes
terraform apply

# Show current state
terraform show

# List resources
terraform state list

# Get specific output
terraform output pipeline_name

# Destroy pipeline only
terraform destroy -target=module.cicd_pipeline

# Destroy everything
terraform destroy
```

---

## 🎓 Next Steps

### 1. Add Approval Stage

Require manual approval before deployment:

```hcl
# Add to modules/cicd-pipeline/main.tf
stage {
  name = "Approval"

  action {
    name     = "ManualApproval"
    category = "Approval"
    owner    = "AWS"
    provider = "Manual"
    version  = "1"

    configuration = {
      CustomData = "Please review and approve deployment"
    }
  }
}
```

### 2. Add Testing Stage

Run automated tests before deployment:

```hcl
stage {
  name = "Test"

  action {
    name             = "Test"
    category         = "Test"
    owner            = "AWS"
    provider         = "CodeBuild"
    version          = "1"
    input_artifacts  = ["source_output"]

    configuration = {
      ProjectName = aws_codebuild_project.test.name
    }
  }
}
```

### 3. Add Notifications

Get notified on pipeline events:

```bash
# Create SNS topic
aws sns create-topic --name pipeline-notifications

# Subscribe to topic
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:ACCOUNT_ID:pipeline-notifications \
  --protocol email \
  --notification-endpoint your-email@example.com
```

### 4. Multi-Environment Pipeline

Deploy to dev → staging → production:
- Create separate ECS services for each environment
- Add approval between environments
- Use different branches for each environment

---

## ✅ Checklist

Before going to production:

- [ ] GitHub connection is AVAILABLE
- [ ] Secrets are stored securely (not in git)
- [ ] Pipeline successfully builds and deploys
- [ ] ECS tasks are healthy after deployment
- [ ] Application is accessible via ALB
- [ ] CloudWatch logs are working
- [ ] Rollback plan is documented
- [ ] Team knows how to monitor pipeline
- [ ] Cost alerts are configured

---

## 🆘 Support

**Terraform Issues:**
- Terraform Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- AWS Provider: https://github.com/hashicorp/terraform-provider-aws

**AWS CodePipeline:**
- Documentation: https://docs.aws.amazon.com/codepipeline/
- Troubleshooting: https://docs.aws.amazon.com/codepipeline/latest/userguide/troubleshooting.html

**GitHub Connection:**
- AWS CodeStar Connections: https://docs.aws.amazon.com/dtconsole/latest/userguide/welcome-connections.html

---

**🎉 Congratulations! Your CI/CD pipeline is now fully automated with Terraform!**

Every git push will automatically build, test, and deploy your application with zero downtime.
