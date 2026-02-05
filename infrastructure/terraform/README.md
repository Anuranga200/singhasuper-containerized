# Singha Loyalty System - Terraform Infrastructure

## 🏗️ Architecture Overview

This Terraform configuration deploys a production-ready, highly available infrastructure on AWS following the **AWS Well-Architected Framework** principles:

### Architecture Components

```
┌─────────────────────────────────────────────────────────────────┐
│                         CloudFront CDN                           │
│                    (Global Edge Locations)                       │
└────────────────┬────────────────────────────┬───────────────────┘
                 │                            │
                 │ Frontend                   │ API
                 ▼                            ▼
        ┌────────────────┐          ┌──────────────────┐
        │   S3 Bucket    │          │  Application     │
        │   (Frontend)   │          │  Load Balancer   │
        └────────────────┘          └────────┬─────────┘
                                              │
                                    ┌─────────┴─────────┐
                                    │                   │
                              ┌─────▼─────┐     ┌──────▼──────┐
                              │ ECS Task  │     │  ECS Task   │
                              │ (Fargate) │     │  (Fargate)  │
                              └─────┬─────┘     └──────┬──────┘
                                    │                  │
                                    └────────┬─────────┘
                                             │
                                    ┌────────▼─────────┐
                                    │   RDS MySQL      │
                                    │  (Multi-AZ)      │
                                    └──────────────────┘
```

### Key Features

✅ **Security**
- VPC with public/private subnets across 2 AZs
- Security groups with least privilege access
- RDS encryption at rest with KMS
- Secrets Manager for credentials
- VPC Flow Logs for monitoring
- Container image scanning in ECR

✅ **Reliability**
- Multi-AZ deployment for high availability
- Auto-scaling for ECS tasks
- ALB health checks with circuit breaker
- Automated RDS backups (7-day retention)
- CloudWatch alarms for monitoring

✅ **Performance**
- CloudFront CDN for global content delivery
- ECS Fargate for serverless containers
- gp3 storage for RDS
- Container Insights for monitoring

✅ **Cost Optimization**
- Fargate Spot instances (80% cost savings)
- Right-sized resources (t3.micro RDS, 256 CPU/512 MB containers)
- ECR lifecycle policies
- S3 lifecycle policies
- CloudFront price class optimization

✅ **Operational Excellence**
- Infrastructure as Code with Terraform
- Modular architecture for reusability
- Comprehensive CloudWatch logging
- Automated deployments

---

## 📋 Prerequisites

Before you begin, ensure you have:

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured
   ```bash
   aws --version
   aws configure
   ```

3. **Terraform** installed (v1.0+)
   ```bash
   terraform --version
   ```

4. **Docker** installed (for building images)
   ```bash
   docker --version
   ```

5. **Git** installed
   ```bash
   git --version
   ```

---

## 🚀 Quick Start Guide

### Step 1: Clone and Navigate

```bash
cd infrastructure/terraform
```

### Step 2: Configure Variables

```bash
# Copy the example file
copy terraform.tfvars.example terraform.tfvars

# Edit with your values (use a text editor)
notepad terraform.tfvars
```

**IMPORTANT**: Update these critical values:
- `db_password`: Strong password (min 8 characters)
- `jwt_secret`: Random 32+ character string
- `aws_region`: Your preferred AWS region

### Step 3: Initialize Terraform

```bash
terraform init
```

This downloads required providers and initializes the backend.

### Step 4: Review the Plan

```bash
terraform plan
```

Review the resources that will be created (~50+ resources).

### Step 5: Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted. Deployment takes **15-20 minutes**.

### Step 6: Save Outputs

```bash
terraform output > deployment-info.txt
```

This saves important endpoints and next steps.

---

## 📦 Post-Deployment Steps

After Terraform completes, follow these steps:

### 1. Build and Push Docker Image

```bash
# Get ECR repository URL from outputs
$ECR_REPO = terraform output -raw ecr_repository_url

# Navigate to server directory
cd ../../server

# Build Docker image
docker build -t ${ECR_REPO}:latest .

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REPO

# Push image
docker push ${ECR_REPO}:latest
```

### 2. Update ECS Service

```bash
# Get cluster and service names
$CLUSTER = terraform output -raw ecs_cluster_name
$SERVICE = terraform output -raw ecs_service_name

# Force new deployment
aws ecs update-service --cluster $CLUSTER --service $SERVICE --force-new-deployment --region us-east-1
```

### 3. Run Database Migrations

```bash
# Get RDS endpoint
$DB_ENDPOINT = terraform output -raw rds_endpoint

# Connect and run migrations
# Option 1: From local machine (if RDS is publicly accessible)
mysql -h $DB_ENDPOINT -u admin -p singha_loyalty < src/db/schema.sql

# Option 2: From ECS task (recommended)
# Use ECS Exec or run a one-time task
```

### 4. Deploy Frontend

```bash
# Get S3 bucket name and CloudFront distribution ID
$BUCKET = terraform output -raw frontend_bucket_name
$DISTRIBUTION = terraform output -raw cloudfront_distribution_id

# Build frontend
cd ../../
npm run build

# Upload to S3
aws s3 sync ./dist s3://${BUCKET}/ --delete

# Invalidate CloudFront cache
aws cloudfront create-invalidation --distribution-id $DISTRIBUTION --paths "/*"
```

### 5. Access Your Application

```bash
# Get URLs
terraform output frontend_url
terraform output api_endpoint
```

---

## 🔧 Configuration Options

### Environment-Specific Configurations

Create separate `.tfvars` files for each environment:

```bash
# Development
terraform apply -var-file="dev.tfvars"

# Staging
terraform apply -var-file="staging.tfvars"

# Production
terraform apply -var-file="prod.tfvars"
```

### Cost Optimization Settings

For **development** environments:
```hcl
db_instance_class       = "db.t3.micro"
multi_az                = false
use_spot_instances      = true
spot_weight             = 100
desired_count           = 1
enable_container_insights = false
```

For **production** environments:
```hcl
db_instance_class       = "db.t3.small"
multi_az                = true
use_spot_instances      = true
spot_weight             = 50
desired_count           = 3
enable_container_insights = true
```

---

## 📊 Monitoring and Logging

### CloudWatch Dashboards

Access CloudWatch Console:
```
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1
```

### Key Metrics to Monitor

1. **ECS Service**
   - CPU Utilization
   - Memory Utilization
   - Task Count

2. **RDS Database**
   - CPU Utilization
   - Free Storage Space
   - Database Connections

3. **ALB**
   - Target Response Time
   - Healthy/Unhealthy Host Count
   - Request Count

### Log Groups

- ECS Logs: `/ecs/singha-loyalty`
- VPC Flow Logs: `/aws/vpc/singha-loyalty-flow-logs`
- RDS Logs: Available in RDS Console

---

## � Security Best Practices

### 1. Secrets Management

**Never commit sensitive data!** Use:
- AWS Secrets Manager (already configured)
- Environment variables
- `.tfvars` files (add to `.gitignore`)

### 2. IAM Roles

All resources use IAM roles with least privilege:
- ECS Task Execution Role: Pull images, write logs
- ECS Task Role: Application permissions
- RDS Monitoring Role: Enhanced monitoring

### 3. Network Security

- RDS in private subnets (no internet access)
- Security groups with specific port rules
- VPC Flow Logs enabled

### 4. Encryption

- RDS encrypted at rest with KMS
- S3 encrypted with AES256
- Secrets Manager for credentials

---

## 🔄 CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [main]
    paths:
      - 'infrastructure/terraform/**'

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        
      - name: Terraform Init
        run: terraform init
        working-directory: infrastructure/terraform
        
      - name: Terraform Plan
        run: terraform plan
        working-directory: infrastructure/terraform
        env:
          TF_VAR_db_password: ${{ secrets.DB_PASSWORD }}
          TF_VAR_jwt_secret: ${{ secrets.JWT_SECRET }}
          
      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: terraform apply -auto-approve
        working-directory: infrastructure/terraform
```

---

## 🧹 Cleanup

To destroy all resources:

```bash
# Review what will be destroyed
terraform plan -destroy

# Destroy infrastructure
terraform destroy
```

**WARNING**: This will delete:
- All ECS tasks and services
- RDS database (snapshot will be created if in production)
- S3 buckets (must be empty first)
- All networking components

---

## 📁 Project Structure

```
infrastructure/terraform/
├── main.tf                 # Root module
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── terraform.tfvars.example # Example configuration
├── README.md               # This file
│
└── modules/
    ├── vpc/                # VPC and networking
    ├── security-groups/    # Security groups
    ├── rds/                # RDS MySQL database
    ├── ecr/                # Container registry
    ├── alb/                # Application Load Balancer
    ├── ecs/                # ECS Fargate cluster
    ├── s3-frontend/        # S3 for frontend hosting
    └── cloudfront/         # CloudFront CDN
```

---

## 🐛 Troubleshooting

### Issue: Terraform Init Fails

```bash
# Clear cache and reinitialize
Remove-Item -Recurse -Force .terraform
terraform init
```

### Issue: ECS Tasks Not Starting

1. Check CloudWatch Logs: `/ecs/singha-loyalty`
2. Verify ECR image exists
3. Check security group rules
4. Verify IAM role permissions

### Issue: Cannot Connect to RDS

1. Verify security group allows traffic from ECS
2. Check RDS is in private subnets
3. Verify credentials in Secrets Manager

### Issue: High Costs

1. Check Fargate Spot usage: `use_spot_instances = true`
2. Reduce task count: `desired_count = 1`
3. Use smaller RDS instance: `db.t3.micro`
4. Review CloudWatch metrics for unused resources

---

## 📚 Additional Resources

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)

---

## 🤝 Support

For issues or questions:
1. Check the troubleshooting section above
2. Review CloudWatch logs
3. Consult AWS documentation
4. Contact your DevOps team

---

## 📝 License

This infrastructure code is part of the Singha Loyalty System project.

---

**Last Updated**: February 2026
**Terraform Version**: >= 1.0
**AWS Provider Version**: ~> 5.0
