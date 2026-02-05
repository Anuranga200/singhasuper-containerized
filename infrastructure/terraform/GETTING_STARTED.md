# 🎯 Getting Started with Terraform Deployment

## Welcome!

This guide will help you deploy the Singha Loyalty System infrastructure to AWS using Terraform. Follow these steps carefully for a successful deployment.

---

## ⏱️ Time Estimate

- **First-time setup**: 60-90 minutes
- **Subsequent deployments**: 20-30 minutes

---

## 📚 Documentation Structure

We've created comprehensive documentation to guide you:

1. **GETTING_STARTED.md** (this file) - Start here!
2. **README.md** - Architecture overview and detailed information
3. **DEPLOYMENT_GUIDE.md** - Step-by-step deployment instructions
4. **QUICK_REFERENCE.md** - Common commands and tasks
5. **COST_ESTIMATION.md** - Detailed cost breakdown and optimization

---

## 🎓 Prerequisites Knowledge

### Required
- Basic understanding of AWS services
- Familiarity with command line/PowerShell
- Understanding of environment variables

### Nice to Have
- Experience with Docker
- Knowledge of Terraform basics
- Understanding of CI/CD concepts

---

## 🛠️ Tools Installation

### 1. Install AWS CLI

**Windows:**
```powershell
# Download from: https://aws.amazon.com/cli/
# Or use Chocolatey:
choco install awscli
```

**Verify:**
```powershell
aws --version
# Expected: aws-cli/2.x.x or higher
```

### 2. Install Terraform

**Windows:**
```powershell
# Download from: https://www.terraform.io/downloads
# Or use Chocolatey:
choco install terraform
```

**Verify:**
```powershell
terraform --version
# Expected: Terraform v1.0.0 or higher
```

### 3. Install Docker

**Windows:**
```powershell
# Download from: https://www.docker.com/products/docker-desktop
```

**Verify:**
```powershell
docker --version
# Expected: Docker version 20.x.x or higher
```

### 4. Configure AWS Credentials

```powershell
aws configure
```

**You'll need:**
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., us-east-1)
- Default output format (json)

**Verify:**
```powershell
aws sts get-caller-identity
# Should show your AWS account information
```

---

## 🚀 Quick Start (5 Steps)

### Step 1: Navigate to Terraform Directory

```powershell
cd infrastructure/terraform
```

### Step 2: Create Configuration File

```powershell
copy terraform.tfvars.example terraform.tfvars
```

### Step 3: Generate Secure Secrets

```powershell
# Generate JWT Secret (32 characters)
-join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})

# Generate Database Password (16 characters)
-join ((65..90) + (97..122) + (48..57) + (33,35,37,42,43,45,61,63,64) | Get-Random -Count 16 | ForEach-Object {[char]$_})
```

### Step 4: Edit Configuration

Open `terraform.tfvars` and update:

```hcl
# REQUIRED - Update these!
db_password = "PASTE_GENERATED_PASSWORD_HERE"
jwt_secret  = "PASTE_GENERATED_SECRET_HERE"

# OPTIONAL - Adjust as needed
aws_region   = "us-east-1"
project_name = "singha-loyalty"
environment  = "production"
```

### Step 5: Deploy!

```powershell
# Initialize
terraform init

# Preview
terraform plan

# Deploy
terraform apply
```

Type `yes` when prompted. Wait 15-20 minutes for deployment to complete.

---

## 📋 Post-Deployment Checklist

After Terraform completes:

- [ ] Save deployment outputs
  ```powershell
  terraform output > deployment-info.txt
  ```

- [ ] Build and push Docker image
  ```powershell
  $ECR_REPO = terraform output -raw ecr_repository_url
  docker build -t ${ECR_REPO}:latest ./server
  aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REPO
  docker push ${ECR_REPO}:latest
  ```

- [ ] Update ECS service
  ```powershell
  $CLUSTER = terraform output -raw ecs_cluster_name
  $SERVICE = terraform output -raw ecs_service_name
  aws ecs update-service --cluster $CLUSTER --service $SERVICE --force-new-deployment
  ```

- [ ] Run database migrations
  ```powershell
  cd ../../server
  node src/db/migrate.js
  ```

- [ ] Deploy frontend
  ```powershell
  cd ../..
  npm run build
  $BUCKET = terraform output -raw frontend_bucket_name
  aws s3 sync ./dist s3://${BUCKET}/ --delete
  ```

- [ ] Test application
  ```powershell
  $API_ENDPOINT = terraform output -raw api_endpoint
  curl "${API_ENDPOINT}/health"
  ```

---

## 🎯 What Gets Created?

### Networking (VPC Module)
- ✅ 1 VPC with DNS support
- ✅ 2 Public subnets (for ALB and ECS)
- ✅ 2 Private subnets (for RDS)
- ✅ 1 Internet Gateway
- ✅ Route tables and associations
- ✅ VPC Flow Logs (optional)

### Security (Security Groups Module)
- ✅ ALB security group (HTTP/HTTPS from internet)
- ✅ ECS security group (port 3000 from ALB)
- ✅ RDS security group (port 3306 from ECS)

### Database (RDS Module)
- ✅ MySQL 8.0 RDS instance
- ✅ DB subnet group
- ✅ Parameter group with optimizations
- ✅ KMS encryption key
- ✅ Secrets Manager for credentials
- ✅ CloudWatch alarms
- ✅ Enhanced monitoring

### Container Registry (ECR Module)
- ✅ ECR repository for Docker images
- ✅ Image scanning enabled
- ✅ Lifecycle policies
- ✅ Encryption at rest

### Load Balancer (ALB Module)
- ✅ Application Load Balancer
- ✅ Target group with health checks
- ✅ HTTP listener (port 80)
- ✅ CloudWatch alarms

### Container Orchestration (ECS Module)
- ✅ ECS Fargate cluster
- ✅ ECS service with auto-scaling
- ✅ Task definition
- ✅ IAM roles (execution and task)
- ✅ CloudWatch log group
- ✅ Auto-scaling policies

### Frontend (S3 + CloudFront Modules)
- ✅ S3 bucket for static hosting
- ✅ CloudFront distribution
- ✅ Origin Access Identity
- ✅ Bucket policies
- ✅ Lifecycle policies

**Total: ~50+ AWS resources**

---

## 💰 Cost Expectations

### Development Environment
- **Monthly**: $25-35 USD
- **Daily**: ~$1 USD
- **Hourly**: ~$0.04 USD

### Production Environment
- **Monthly**: $80-120 USD
- **Daily**: ~$3 USD
- **Hourly**: ~$0.12 USD

See `COST_ESTIMATION.md` for detailed breakdown.

---

## 🔒 Security Considerations

### Before Deployment

1. **Strong Passwords**
   - Database password: min 8 characters, mix of letters/numbers/symbols
   - JWT secret: min 32 characters, random

2. **AWS Account Security**
   - Enable MFA on root account
   - Use IAM users with least privilege
   - Enable CloudTrail logging

3. **Secrets Management**
   - Never commit `terraform.tfvars` to Git
   - Use AWS Secrets Manager (already configured)
   - Rotate secrets regularly

### After Deployment

1. **Network Security**
   - Review security group rules
   - Enable VPC Flow Logs
   - Consider AWS WAF for CloudFront

2. **Monitoring**
   - Set up CloudWatch alarms
   - Enable AWS GuardDuty
   - Review access logs regularly

3. **Compliance**
   - Enable encryption at rest (already done)
   - Enable encryption in transit
   - Regular security audits

---

## 🐛 Common Issues

### Issue: "terraform: command not found"
**Solution**: Terraform not installed or not in PATH
```powershell
# Verify installation
terraform --version

# If not found, reinstall or add to PATH
```

### Issue: "Error: No valid credential sources found"
**Solution**: AWS credentials not configured
```powershell
aws configure
# Enter your AWS credentials
```

### Issue: "Error: Error creating DB Instance: DBInstanceAlreadyExists"
**Solution**: RDS instance with same name exists
```powershell
# Either delete existing instance or change project_name in terraform.tfvars
```

### Issue: "Error: error creating ECR repository: RepositoryAlreadyExistsException"
**Solution**: ECR repository already exists
```powershell
# Import existing repository
terraform import module.ecr.aws_ecr_repository.main singha-loyalty-backend
```

### Issue: High costs
**Solution**: Optimize configuration
```hcl
# In terraform.tfvars
desired_count = 1
db_instance_class = "db.t3.micro"
use_spot_instances = true
enable_container_insights = false
```

---

## 📞 Getting Help

### Documentation
1. Read `README.md` for architecture details
2. Check `DEPLOYMENT_GUIDE.md` for step-by-step instructions
3. Review `QUICK_REFERENCE.md` for common commands
4. See `COST_ESTIMATION.md` for cost optimization

### AWS Resources
- AWS Console: https://console.aws.amazon.com
- AWS Documentation: https://docs.aws.amazon.com
- AWS Support: https://console.aws.amazon.com/support

### Terraform Resources
- Terraform Docs: https://www.terraform.io/docs
- AWS Provider: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- Community Forum: https://discuss.hashicorp.com/c/terraform-core

### Troubleshooting
1. Check CloudWatch Logs
2. Review Terraform output
3. Verify AWS credentials
4. Check service quotas
5. Review security groups

---

## 🎓 Learning Path

### Beginner
1. ✅ Complete this getting started guide
2. ✅ Deploy to development environment
3. ✅ Explore AWS Console
4. ✅ Review created resources
5. ✅ Test application

### Intermediate
1. ✅ Customize configuration
2. ✅ Set up monitoring
3. ✅ Configure auto-scaling
4. ✅ Implement CI/CD
5. ✅ Optimize costs

### Advanced
1. ✅ Multi-environment setup
2. ✅ Custom domain with SSL
3. ✅ Advanced monitoring
4. ✅ Disaster recovery
5. ✅ Security hardening

---

## 🎉 Success Criteria

You'll know your deployment is successful when:

✅ Terraform apply completes without errors
✅ All ~50 resources are created
✅ ECS tasks are running (check AWS Console)
✅ Health endpoint returns 200 OK
✅ Frontend loads in browser
✅ API responds to requests
✅ Database is accessible
✅ CloudWatch logs are flowing

---

## 🚀 Next Steps

After successful deployment:

1. **Configure Custom Domain** (optional)
   - Register domain in Route 53
   - Request SSL certificate in ACM
   - Update CloudFront distribution

2. **Set Up CI/CD**
   - GitHub Actions for automated deployments
   - Automated testing
   - Blue/green deployments

3. **Enable Advanced Monitoring**
   - Custom CloudWatch dashboards
   - SNS alerts for critical events
   - AWS X-Ray for tracing

4. **Implement Backup Strategy**
   - Automated RDS snapshots (already enabled)
   - S3 versioning (already enabled)
   - Disaster recovery plan

5. **Security Hardening**
   - AWS WAF on CloudFront
   - AWS Shield for DDoS protection
   - Regular security audits

---

## 📝 Feedback

This is a living document. If you find:
- Errors or outdated information
- Missing steps or unclear instructions
- Opportunities for improvement

Please update the documentation or contact the DevOps team.

---

## 🙏 Acknowledgments

This infrastructure follows:
- AWS Well-Architected Framework
- Terraform best practices
- Security best practices
- Cost optimization strategies

---

**Ready to deploy? Start with Step 1 above!**

**Questions? Check the other documentation files or contact support.**

---

**Version**: 1.0
**Last Updated**: February 2026
**Maintained By**: DevOps Team
