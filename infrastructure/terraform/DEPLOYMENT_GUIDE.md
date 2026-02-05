# 🚀 Step-by-Step Deployment Guide

This guide walks you through deploying the Singha Loyalty System infrastructure from scratch.

---

## 📋 Pre-Deployment Checklist

Before starting, ensure you have:

- [ ] AWS Account with admin access
- [ ] AWS CLI installed and configured
- [ ] Terraform installed (v1.0+)
- [ ] Docker installed
- [ ] Git installed
- [ ] Text editor (VS Code, Notepad++, etc.)

---

## Phase 1: Initial Setup (10 minutes)

### Step 1.1: Verify AWS Credentials

```powershell
# Check AWS CLI is configured
aws sts get-caller-identity

# Expected output shows your AWS account ID
```

If this fails, configure AWS CLI:
```powershell
aws configure
# Enter: Access Key ID, Secret Access Key, Region (us-east-1), Output format (json)
```

### Step 1.2: Verify Terraform Installation

```powershell
terraform version

# Expected: Terraform v1.0.0 or higher
```

### Step 1.3: Navigate to Terraform Directory

```powershell
cd infrastructure/terraform
```

---

## Phase 2: Configuration (15 minutes)

### Step 2.1: Create Configuration File

```powershell
# Copy the example file
copy terraform.tfvars.example terraform.tfvars
```

### Step 2.2: Generate Secure Secrets

**IMPORTANT**: Use strong, random values for production!

```powershell
# Generate random JWT secret (PowerShell)
-join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})

# Generate random database password
-join ((65..90) + (97..122) + (48..57) + (33,35,37,42,43,45,61,63,64) | Get-Random -Count 16 | ForEach-Object {[char]$_})
```

### Step 2.3: Edit Configuration

Open `terraform.tfvars` in your text editor and update:

```hcl
# REQUIRED: Update these values
aws_region   = "us-east-1"              # Your preferred region
db_password  = "YOUR_GENERATED_PASSWORD" # From Step 2.2
jwt_secret   = "YOUR_GENERATED_SECRET"   # From Step 2.2

# OPTIONAL: Adjust for your environment
environment  = "production"              # or "development", "staging"
project_name = "singha-loyalty"

# Cost optimization (adjust based on needs)
db_instance_class = "db.t3.micro"       # Cheapest: db.t3.micro
desired_count     = 2                    # Number of ECS tasks
use_spot_instances = true                # Use Spot for 70% cost savings
```

### Step 2.4: Review Configuration

```powershell
# Validate your configuration
terraform fmt
terraform validate
```

---

## Phase 3: Infrastructure Deployment (20 minutes)

### Step 3.1: Initialize Terraform

```powershell
terraform init
```

**What this does:**
- Downloads AWS provider plugins
- Initializes backend configuration
- Prepares working directory

**Expected output:**
```
Terraform has been successfully initialized!
```

### Step 3.2: Review Deployment Plan

```powershell
terraform plan
```

**What to look for:**
- Number of resources to create (~50+)
- No errors or warnings
- Resource names match your project

**Expected output:**
```
Plan: 52 to add, 0 to change, 0 to destroy.
```

### Step 3.3: Deploy Infrastructure

```powershell
terraform apply
```

**What happens:**
1. Terraform shows the plan again
2. Type `yes` to confirm
3. Resources are created in order:
   - VPC and networking (2 min)
   - Security groups (1 min)
   - RDS database (10 min) ⏰ Longest step
   - ECR repository (1 min)
   - ALB (2 min)
   - ECS cluster and service (3 min)
   - S3 and CloudFront (2 min)

**Total time: 15-20 minutes**

☕ Grab a coffee while RDS is being created!

### Step 3.4: Save Deployment Information

```powershell
# Save all outputs to a file
terraform output > deployment-info.txt

# View specific outputs
terraform output ecr_repository_url
terraform output api_endpoint
terraform output frontend_url
```

---

## Phase 4: Application Deployment (30 minutes)

### Step 4.1: Build and Push Docker Image

```powershell
# Get ECR repository URL
$ECR_REPO = terraform output -raw ecr_repository_url
$AWS_REGION = terraform output -raw aws_region

# Navigate to server directory
cd ../../server

# Build Docker image
docker build -t ${ECR_REPO}:latest .

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO

# Push image to ECR
docker push ${ECR_REPO}:latest
```

**Troubleshooting:**
- If Docker build fails, check Dockerfile exists
- If ECR login fails, verify AWS credentials
- If push fails, check network connection

### Step 4.2: Update ECS Service

```powershell
# Return to terraform directory
cd ../infrastructure/terraform

# Get cluster and service names
$CLUSTER = terraform output -raw ecs_cluster_name
$SERVICE = terraform output -raw ecs_service_name
$AWS_REGION = terraform output -raw aws_region

# Force new deployment with updated image
aws ecs update-service `
    --cluster $CLUSTER `
    --service $SERVICE `
    --force-new-deployment `
    --region $AWS_REGION
```

**Wait 3-5 minutes** for new tasks to start.

### Step 4.3: Verify ECS Tasks are Running

```powershell
# Check service status
aws ecs describe-services `
    --cluster $CLUSTER `
    --services $SERVICE `
    --region $AWS_REGION `
    --query 'services[0].{desired:desiredCount,running:runningCount,pending:pendingCount}'
```

**Expected output:**
```json
{
    "desired": 2,
    "running": 2,
    "pending": 0
}
```

### Step 4.4: Check Application Health

```powershell
# Get API endpoint
$API_ENDPOINT = terraform output -raw api_endpoint

# Test health endpoint
curl "${API_ENDPOINT}/health"
```

**Expected response:**
```json
{
  "status": "healthy",
  "timestamp": "2026-02-03T...",
  "uptime": 123.45
}
```

---

## Phase 5: Database Setup (15 minutes)

### Step 5.1: Get Database Connection Info

```powershell
$DB_ENDPOINT = terraform output -raw rds_endpoint
$DB_NAME = terraform output -raw rds_database_name
$DB_USER = "admin"  # From your terraform.tfvars
$DB_PASSWORD = "YOUR_PASSWORD"  # From your terraform.tfvars
```

### Step 5.2: Connect to Database

**Option A: From Local Machine (if RDS is publicly accessible)**

```powershell
mysql -h $DB_ENDPOINT -u $DB_USER -p$DB_PASSWORD $DB_NAME
```

**Option B: Using ECS Exec (Recommended)**

```powershell
# Enable ECS Exec on service (one-time setup)
aws ecs update-service `
    --cluster $CLUSTER `
    --service $SERVICE `
    --enable-execute-command `
    --region $AWS_REGION

# Get task ARN
$TASK_ARN = aws ecs list-tasks `
    --cluster $CLUSTER `
    --service-name $SERVICE `
    --region $AWS_REGION `
    --query 'taskArns[0]' `
    --output text

# Execute command in container
aws ecs execute-command `
    --cluster $CLUSTER `
    --task $TASK_ARN `
    --container singha-loyalty-container `
    --interactive `
    --command "/bin/sh" `
    --region $AWS_REGION
```

### Step 5.3: Run Database Migrations

```powershell
# From server directory
cd ../../server

# Run migrations
node src/db/migrate.js

# Seed initial data (optional)
node src/db/seed.js
```

---

## Phase 6: Frontend Deployment (10 minutes)

### Step 6.1: Build Frontend

```powershell
# Navigate to project root
cd ../..

# Install dependencies (if not already done)
npm install

# Build production bundle
npm run build
```

### Step 6.2: Deploy to S3

```powershell
# Get S3 bucket name
cd infrastructure/terraform
$BUCKET = terraform output -raw frontend_bucket_name
$DISTRIBUTION = terraform output -raw cloudfront_distribution_id

# Upload files to S3
cd ../..
aws s3 sync ./dist s3://${BUCKET}/ --delete

# Invalidate CloudFront cache
aws cloudfront create-invalidation `
    --distribution-id $DISTRIBUTION `
    --paths "/*"
```

### Step 6.3: Verify Frontend

```powershell
# Get frontend URL
cd infrastructure/terraform
$FRONTEND_URL = terraform output -raw frontend_url

# Open in browser
Start-Process $FRONTEND_URL
```

---

## Phase 7: Verification (10 minutes)

### Step 7.1: Test API Endpoints

```powershell
$API_ENDPOINT = terraform output -raw api_endpoint

# Test health endpoint
curl "${API_ENDPOINT}/health"

# Test customer registration (example)
curl -X POST "${API_ENDPOINT}/api/customers/register" `
    -H "Content-Type: application/json" `
    -d '{"name":"Test User","email":"test@example.com","phone":"1234567890"}'
```

### Step 7.2: Check CloudWatch Logs

```powershell
# View ECS logs
aws logs tail /ecs/singha-loyalty --follow --region $AWS_REGION
```

### Step 7.3: Monitor Resources

Visit AWS Console:
- **ECS**: https://console.aws.amazon.com/ecs/
- **RDS**: https://console.aws.amazon.com/rds/
- **CloudWatch**: https://console.aws.amazon.com/cloudwatch/

---

## Phase 8: Post-Deployment Configuration

### Step 8.1: Set Up Monitoring Alerts

```powershell
# Create SNS topic for alerts
aws sns create-topic --name singha-loyalty-alerts --region $AWS_REGION

# Subscribe your email
aws sns subscribe `
    --topic-arn arn:aws:sns:$AWS_REGION:ACCOUNT_ID:singha-loyalty-alerts `
    --protocol email `
    --notification-endpoint your-email@example.com
```

### Step 8.2: Configure Auto Scaling (if not enabled)

Auto scaling is already configured in Terraform, but you can adjust:

```powershell
# Edit terraform.tfvars
enable_autoscaling = true
min_capacity = 2
max_capacity = 10
cpu_target_value = 70
memory_target_value = 80

# Apply changes
terraform apply
```

### Step 8.3: Set Up Backup Verification

```powershell
# Verify RDS automated backups
aws rds describe-db-instances `
    --db-instance-identifier singha-loyalty-db `
    --query 'DBInstances[0].{BackupRetention:BackupRetentionPeriod,PreferredBackupWindow:PreferredBackupWindow}' `
    --region $AWS_REGION
```

---

## 🎉 Deployment Complete!

Your infrastructure is now fully deployed and operational!

### Access Points

- **Frontend**: https://[cloudfront-domain].cloudfront.net
- **API**: http://[alb-dns-name].us-east-1.elb.amazonaws.com
- **Database**: [rds-endpoint]:3306

### Next Steps

1. **Configure Custom Domain** (optional)
   - Request SSL certificate in ACM
   - Update CloudFront distribution
   - Configure Route 53 DNS

2. **Set Up CI/CD Pipeline**
   - GitHub Actions for automated deployments
   - CodePipeline for AWS-native solution

3. **Enable Additional Monitoring**
   - Set up CloudWatch dashboards
   - Configure SNS alerts
   - Enable AWS X-Ray for tracing

4. **Security Hardening**
   - Enable AWS WAF on CloudFront
   - Configure AWS Shield
   - Set up AWS GuardDuty

---

## 🐛 Common Issues and Solutions

### Issue: ECS Tasks Keep Restarting

**Solution:**
```powershell
# Check logs
aws logs tail /ecs/singha-loyalty --follow

# Common causes:
# 1. Database connection failed - verify RDS endpoint
# 2. Missing environment variables - check task definition
# 3. Application error - review application logs
```

### Issue: Cannot Access API

**Solution:**
```powershell
# Check ALB target health
aws elbv2 describe-target-health `
    --target-group-arn [TARGET_GROUP_ARN]

# Verify security groups allow traffic
# Check ECS tasks are running
```

### Issue: High AWS Costs

**Solution:**
```powershell
# Reduce costs by:
# 1. Using Spot instances (already enabled)
# 2. Reducing task count
desired_count = 1

# 3. Using smaller RDS instance
db_instance_class = "db.t3.micro"

# 4. Disabling Container Insights
enable_container_insights = false

# Apply changes
terraform apply
```

---

## 📞 Support

For issues:
1. Check CloudWatch Logs
2. Review this guide
3. Consult AWS documentation
4. Contact DevOps team

---

**Deployment Guide Version**: 1.0
**Last Updated**: February 2026
