# 🏗️ Infrastructure Directory

This directory contains all infrastructure-related files for the Singha Loyalty System.

---

## 📁 Directory Structure

```
infrastructure/
├── terraform/                          ← **START HERE for Terraform deployment**
│   ├── 00-START-HERE.md               ← Navigation guide
│   ├── GETTING_STARTED.md             ← Quick start guide
│   ├── DEPLOYMENT_GUIDE.md            ← Detailed instructions
│   ├── DEPLOYMENT_CHECKLIST.md        ← Step-by-step checklist
│   ├── QUICK_REFERENCE.md             ← Common commands
│   ├── ARCHITECTURE.md                ← Architecture details
│   ├── COST_ESTIMATION.md             ← Cost breakdown
│   ├── IMPLEMENTATION_SUMMARY.md      ← What was built
│   ├── README.md                      ← Terraform overview
│   ├── main.tf                        ← Root Terraform module
│   ├── variables.tf                   ← Input variables
│   ├── outputs.tf                     ← Output values
│   ├── terraform.tfvars.example       ← Configuration template
│   ├── deploy.bat                     ← Deployment script
│   ├── .gitignore                     ← Git ignore rules
│   └── modules/                       ← Terraform modules
│       ├── vpc/                       ← VPC and networking
│       ├── security-groups/           ← Security groups
│       ├── rds/                       ← RDS MySQL database
│       ├── ecr/                       ← Container registry
│       ├── alb/                       ← Load balancer
│       ├── ecs/                       ← ECS Fargate
│       ├── s3-frontend/               ← S3 for frontend
│       └── cloudfront/                ← CloudFront CDN
│
├── cloudformation-ecs.yaml            ← Legacy CloudFormation (reference)
├── cloudformation-serverless.yaml     ← Legacy (empty)
├── frontend-pipeline.yaml             ← CI/CD for frontend
├── pipeline.yaml                      ← CI/CD for backend
├── buildspec.yml                      ← Build spec for backend
├── buildspec-frontend.yml             ← Build spec for frontend
├── deploy-frontend-pipeline.sh        ← Frontend pipeline deployment
├── deploy-frontend-pipeline.bat       ← Frontend pipeline (Windows)
└── deploy-pipeline.sh                 ← Backend pipeline deployment
```

---

## 🚀 Quick Start

### For Terraform Deployment (Recommended)

```powershell
# Navigate to terraform directory
cd infrastructure/terraform

# Start with the navigation guide
# Read: 00-START-HERE.md

# Then follow the quick start
# Read: GETTING_STARTED.md
```

### For CloudFormation (Legacy)

The CloudFormation templates are provided for reference. **We recommend using Terraform** for new deployments.

---

## 🎯 What's Available

### Terraform Infrastructure (New - Recommended)
- ✅ Production-ready infrastructure
- ✅ AWS Well-Architected Framework compliant
- ✅ Comprehensive documentation (8 guides)
- ✅ Cost-optimized ($25-300/month)
- ✅ Modular and maintainable
- ✅ Security best practices

**Location**: `infrastructure/terraform/`
**Start**: `infrastructure/terraform/00-START-HERE.md`

### CloudFormation Templates (Legacy)
- ⚠️ Reference implementation
- ⚠️ Less flexible than Terraform
- ⚠️ Limited documentation

**Location**: `infrastructure/cloudformation-ecs.yaml`

### CI/CD Pipelines
- Frontend pipeline (CodePipeline + S3 + CloudFront)
- Backend pipeline (CodePipeline + CodeBuild + ECS)

**Location**: `infrastructure/*.yaml`

---

## 📊 Comparison: Terraform vs CloudFormation

| Feature | Terraform | CloudFormation |
|---------|-----------|----------------|
| Documentation | 8 comprehensive guides | Basic |
| Modularity | Highly modular (8 modules) | Monolithic |
| Cost Optimization | Built-in (Spot, auto-scaling) | Manual |
| Security | Multi-layer, best practices | Basic |
| Maintainability | Excellent | Good |
| Learning Curve | Moderate | Moderate |
| **Recommendation** | ✅ **Use This** | Reference only |

---

## 💰 Cost Estimates

### Terraform Infrastructure

| Environment | Monthly Cost | Use Case |
|-------------|--------------|----------|
| Development | $25-35 | Testing, development |
| Production (Low) | $80-120 | Small apps, startups |
| Production (High) | $200-300 | Growing apps, more traffic |

**See**: `terraform/COST_ESTIMATION.md` for detailed breakdown

---

## 🏗️ Architecture Overview

### Terraform Infrastructure

```
Internet
   │
   ├─→ CloudFront CDN
   │      ├─→ S3 (Frontend)
   │      └─→ ALB (API)
   │             └─→ ECS Fargate (2-10 tasks)
   │                    └─→ RDS MySQL
   │
   └─→ Route 53 (Optional)
```

**Components**:
- VPC with public/private subnets
- Application Load Balancer
- ECS Fargate cluster (auto-scaling)
- RDS MySQL (encrypted, backed up)
- S3 + CloudFront for frontend
- ECR for Docker images
- CloudWatch for monitoring

**See**: `terraform/ARCHITECTURE.md` for detailed diagrams

---

## 📚 Documentation

### Terraform Documentation (Comprehensive)

1. **[00-START-HERE.md](./terraform/00-START-HERE.md)** - Navigation guide
2. **[GETTING_STARTED.md](./terraform/GETTING_STARTED.md)** - Quick start (5 steps)
3. **[DEPLOYMENT_GUIDE.md](./terraform/DEPLOYMENT_GUIDE.md)** - Detailed instructions
4. **[DEPLOYMENT_CHECKLIST.md](./terraform/DEPLOYMENT_CHECKLIST.md)** - Step-by-step checklist
5. **[QUICK_REFERENCE.md](./terraform/QUICK_REFERENCE.md)** - Common commands
6. **[ARCHITECTURE.md](./terraform/ARCHITECTURE.md)** - Architecture details
7. **[COST_ESTIMATION.md](./terraform/COST_ESTIMATION.md)** - Cost breakdown
8. **[IMPLEMENTATION_SUMMARY.md](./terraform/IMPLEMENTATION_SUMMARY.md)** - What was built
9. **[README.md](./terraform/README.md)** - Terraform overview

### CloudFormation Documentation

- Basic usage instructions in the YAML files
- See server/readme/ for deployment guides

---

## 🎓 Prerequisites

### For Terraform Deployment

**Required Tools**:
- AWS CLI (configured)
- Terraform (v1.0+)
- Docker
- Git

**Required Knowledge**:
- Basic AWS understanding
- Command line familiarity
- Basic networking concepts

**See**: `terraform/GETTING_STARTED.md` for installation instructions

---

## 🚀 Deployment Options

### Option 1: Terraform (Recommended)

**Pros**:
- ✅ Production-ready
- ✅ Well-documented
- ✅ Cost-optimized
- ✅ Modular
- ✅ Maintainable

**Time**: 90 minutes (first time), 20 minutes (subsequent)

**Start**: `cd terraform && read 00-START-HERE.md`

### Option 2: CloudFormation (Legacy)

**Pros**:
- ✅ AWS-native
- ✅ Simple for basic deployments

**Cons**:
- ⚠️ Less flexible
- ⚠️ Limited documentation
- ⚠️ Harder to maintain

**Time**: 60 minutes

**Start**: Review `cloudformation-ecs.yaml`

### Option 3: Manual (Not Recommended)

**Pros**:
- ✅ Full control
- ✅ Learn AWS services

**Cons**:
- ❌ Time-consuming
- ❌ Error-prone
- ❌ Not reproducible
- ❌ Hard to maintain

**Time**: 4-6 hours

---

## 🔐 Security Considerations

### Terraform Implementation

✅ **Network Security**
- VPC with public/private subnets
- Security groups with least privilege
- VPC Flow Logs

✅ **Data Security**
- RDS encryption at rest (KMS)
- S3 encryption (AES-256)
- Secrets Manager for credentials
- TLS/SSL for data in transit

✅ **Access Control**
- IAM roles with minimal permissions
- No hardcoded secrets
- Origin Access Identity for S3

✅ **Monitoring**
- CloudWatch logs
- CloudWatch alarms
- Container Insights

**See**: `terraform/ARCHITECTURE.md` for security details

---

## 📊 Monitoring & Logging

### CloudWatch Integration

**Logs**:
- `/ecs/singha-loyalty` - Application logs
- `/aws/vpc/singha-loyalty-flow-logs` - Network traffic
- RDS error and slow query logs

**Metrics**:
- ECS: CPU, Memory, Task Count
- RDS: CPU, Storage, Connections
- ALB: Request Count, Response Time

**Alarms**:
- CPU/Memory utilization
- Unhealthy targets
- Database storage
- Response time

---

## 🔄 CI/CD Pipelines

### Frontend Pipeline

**File**: `frontend-pipeline.yaml`

**Flow**:
1. Source: GitHub/CodeCommit
2. Build: npm run build
3. Deploy: S3 + CloudFront invalidation

**Deploy**:
```bash
./deploy-frontend-pipeline.sh
# or
./deploy-frontend-pipeline.bat
```

### Backend Pipeline

**File**: `pipeline.yaml`

**Flow**:
1. Source: GitHub/CodeCommit
2. Build: Docker image
3. Push: ECR
4. Deploy: ECS

**Deploy**:
```bash
./deploy-pipeline.sh
```

---

## 🎯 Choosing the Right Approach

### Use Terraform If:
- ✅ You want production-ready infrastructure
- ✅ You need comprehensive documentation
- ✅ You want cost optimization
- ✅ You need modularity and reusability
- ✅ You want to follow best practices

### Use CloudFormation If:
- ✅ You prefer AWS-native tools
- ✅ You have existing CloudFormation expertise
- ✅ You need simple, basic deployment

### Use Manual If:
- ✅ You're learning AWS services
- ✅ You need complete customization
- ✅ You have specific requirements

**Recommendation**: **Use Terraform** for new deployments

---

## 📞 Getting Help

### Documentation
1. Start with `terraform/00-START-HERE.md`
2. Follow `terraform/GETTING_STARTED.md`
3. Reference `terraform/QUICK_REFERENCE.md`
4. Consult `terraform/DEPLOYMENT_GUIDE.md`

### AWS Resources
- AWS Console: https://console.aws.amazon.com
- AWS Documentation: https://docs.aws.amazon.com
- AWS Support: https://console.aws.amazon.com/support

### Terraform Resources
- Terraform Docs: https://www.terraform.io/docs
- AWS Provider: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- Community: https://discuss.hashicorp.com/c/terraform-core

---

## 🎉 Next Steps

### For New Deployments

1. **Navigate to Terraform directory**
   ```powershell
   cd infrastructure/terraform
   ```

2. **Read the navigation guide**
   ```powershell
   # Open: 00-START-HERE.md
   ```

3. **Follow the quick start**
   ```powershell
   # Open: GETTING_STARTED.md
   ```

4. **Deploy!**
   ```powershell
   terraform init
   terraform plan
   terraform apply
   ```

### For Existing Deployments

1. **Review current infrastructure**
2. **Check for updates**
3. **Plan migration to Terraform** (if using CloudFormation)
4. **Optimize costs** (see COST_ESTIMATION.md)

---

## 📝 Maintenance

### Regular Tasks

**Daily**:
- Monitor CloudWatch dashboards
- Review application logs

**Weekly**:
- Review cost reports
- Check security alerts

**Monthly**:
- Update dependencies
- Security audit
- Cost optimization

**Quarterly**:
- Architecture review
- Disaster recovery testing
- Documentation updates

**See**: `terraform/DEPLOYMENT_CHECKLIST.md` for detailed maintenance schedule

---

## ✨ Summary

This infrastructure directory provides:

✅ **Terraform Implementation** (Recommended)
- Production-ready infrastructure
- 8 comprehensive documentation files
- Cost-optimized ($25-300/month)
- Security best practices
- Auto-scaling and monitoring

✅ **CloudFormation Templates** (Legacy)
- Reference implementation
- Basic deployment

✅ **CI/CD Pipelines**
- Frontend and backend pipelines
- Automated deployments

**Start Here**: `infrastructure/terraform/00-START-HERE.md`

---

**Last Updated**: February 2026
**Maintained By**: DevOps Team
**Next Review**: May 2026
