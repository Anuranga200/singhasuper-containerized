# 💰 AWS Cost Estimation Guide

## Monthly Cost Breakdown

This document provides detailed cost estimates for running the Singha Loyalty System on AWS.

---

## 🎯 Cost Summary

### Development Environment
**Estimated Monthly Cost: $25-35 USD**

### Production Environment (Low Traffic)
**Estimated Monthly Cost: $80-120 USD**

### Production Environment (High Traffic)
**Estimated Monthly Cost: $200-300 USD**

---

## 📊 Detailed Cost Analysis

### 1. Compute (ECS Fargate)

#### Development Configuration
```
Tasks: 1
CPU: 0.25 vCPU
Memory: 0.5 GB
Spot: 100%

Cost Calculation:
- Fargate Spot: $0.01334375 per vCPU-hour
- Fargate Spot: $0.00146484 per GB-hour

Monthly Cost:
- CPU: 0.25 × $0.01334375 × 730 hours = $2.43
- Memory: 0.5 × $0.00146484 × 730 hours = $0.53
Total: ~$3/month
```

#### Production Configuration (2 tasks, 80% Spot)
```
Tasks: 2
CPU: 0.25 vCPU each
Memory: 0.5 GB each
Spot: 80%, On-Demand: 20%

Monthly Cost:
- Spot (80%): 2 × 0.8 × ($2.43 + $0.53) = $4.74
- On-Demand (20%): 2 × 0.2 × ($4.86 + $1.07) = $2.37
Total: ~$7/month
```

#### High Traffic (5 tasks)
```
Tasks: 5 (average with auto-scaling)
Monthly Cost: ~$18/month
```

---

### 2. Database (RDS MySQL)

#### db.t3.micro (Development)
```
Instance: db.t3.micro
Storage: 20 GB gp3
Multi-AZ: No
Backup: 7 days

Cost Breakdown:
- Instance: $0.017/hour × 730 hours = $12.41
- Storage: 20 GB × $0.115/GB = $2.30
- Backup: 20 GB × $0.095/GB = $1.90
Total: ~$17/month
```

#### db.t3.small (Production)
```
Instance: db.t3.small
Storage: 20 GB gp3
Multi-AZ: Yes
Backup: 7 days

Cost Breakdown:
- Instance: $0.034/hour × 730 hours × 2 (Multi-AZ) = $49.64
- Storage: 20 GB × $0.115/GB × 2 = $4.60
- Backup: 20 GB × $0.095/GB = $1.90
Total: ~$56/month
```

#### db.t3.medium (High Traffic)
```
Instance: db.t3.medium
Storage: 50 GB gp3
Multi-AZ: Yes

Cost Breakdown:
- Instance: $0.068/hour × 730 hours × 2 = $99.28
- Storage: 50 GB × $0.115/GB × 2 = $11.50
- Backup: 50 GB × $0.095/GB = $4.75
Total: ~$116/month
```

---

### 3. Load Balancer (ALB)

```
ALB Hours: 730 hours/month
LCU Hours: ~10 LCU-hours/month (low traffic)

Cost Breakdown:
- ALB: $0.0225/hour × 730 = $16.43
- LCU: $0.008/LCU-hour × 10 × 730 = $58.40
Total: ~$75/month

Note: LCU cost varies with traffic
- Low traffic: ~$20/month
- Medium traffic: ~$50/month
- High traffic: ~$100/month
```

---

### 4. Container Registry (ECR)

```
Storage: 2 GB (average)
Data Transfer: 10 GB/month

Cost Breakdown:
- Storage: 2 GB × $0.10/GB = $0.20
- Data Transfer: First 1 GB free, then $0.09/GB
  9 GB × $0.09 = $0.81
Total: ~$1/month
```

---

### 5. Frontend (S3 + CloudFront)

#### S3 Storage
```
Storage: 500 MB
Requests: 10,000 GET requests/month

Cost Breakdown:
- Storage: 0.5 GB × $0.023/GB = $0.01
- GET Requests: 10,000 × $0.0004/1000 = $0.004
Total: ~$0.01/month (negligible)
```

#### CloudFront
```
Data Transfer: 50 GB/month (low traffic)
Requests: 100,000 requests/month

Cost Breakdown:
- Data Transfer: 50 GB × $0.085/GB = $4.25
- Requests: 100,000 × $0.0075/10,000 = $0.075
Total: ~$4.50/month

High Traffic (500 GB):
- Data Transfer: 500 GB × $0.085/GB = $42.50
- Requests: 1,000,000 × $0.0075/10,000 = $0.75
Total: ~$43/month
```

---

### 6. Monitoring & Logging

#### CloudWatch Logs
```
Log Ingestion: 5 GB/month
Log Storage: 10 GB/month

Cost Breakdown:
- Ingestion: 5 GB × $0.50/GB = $2.50
- Storage: 10 GB × $0.03/GB = $0.30
Total: ~$3/month
```

#### Container Insights (Optional)
```
Metrics: 10 custom metrics
Cost: 10 × $0.30 = $3/month
```

---

### 7. Secrets Manager

```
Secrets: 2 secrets (DB credentials, JWT secret)
API Calls: 10,000/month

Cost Breakdown:
- Secrets: 2 × $0.40 = $0.80
- API Calls: First 10,000 free
Total: ~$1/month
```

---

### 8. VPC & Networking

#### VPC Flow Logs
```
Log Data: 2 GB/month
Cost: 2 GB × $0.50/GB = $1/month
```

#### NAT Gateway (if enabled)
```
NAT Gateway: $0.045/hour × 730 = $32.85
Data Processing: 10 GB × $0.045/GB = $0.45
Total: ~$33/month

Note: Disabled by default to save costs
```

---

## 💡 Cost Optimization Strategies

### 1. Use Fargate Spot (Enabled by Default)
**Savings: 70%**
```
Regular Fargate: $7/month
Fargate Spot: $2/month
Savings: $5/month per task
```

### 2. Right-Size RDS Instance
**Savings: 50%**
```
db.t3.small: $56/month
db.t3.micro: $17/month
Savings: $39/month
```

### 3. Reduce Task Count During Off-Hours
**Savings: 30-50%**
```
# Use scheduled scaling
Peak hours (8am-8pm): 3 tasks
Off-peak (8pm-8am): 1 task
Average: 2 tasks instead of 3
Savings: ~$3/month
```

### 4. Optimize CloudWatch Logs
**Savings: 40%**
```
# Reduce log retention
From: 30 days
To: 7 days
Savings: ~$1/month

# Filter unnecessary logs
Savings: ~$1/month
```

### 5. Use S3 Lifecycle Policies
**Savings: 60%**
```
# Move old versions to Glacier
Standard: $0.023/GB
Glacier: $0.004/GB
Savings: ~$0.10/month (minimal but good practice)
```

### 6. Disable Container Insights in Dev
**Savings: $3/month**

### 7. Use Reserved Capacity (Long-term)
**Savings: 30-50%**
```
# For production workloads
1-year commitment: 30% savings
3-year commitment: 50% savings
```

---

## 📈 Cost Scaling Scenarios

### Scenario 1: Startup (0-1000 users)
```
Configuration:
- 1 ECS task (Spot)
- db.t3.micro
- Minimal traffic

Monthly Cost: $25-35
```

### Scenario 2: Growing (1000-10000 users)
```
Configuration:
- 2-3 ECS tasks (80% Spot)
- db.t3.small (Multi-AZ)
- Moderate traffic

Monthly Cost: $80-120
```

### Scenario 3: Established (10000-100000 users)
```
Configuration:
- 5-10 ECS tasks (auto-scaling)
- db.t3.medium (Multi-AZ)
- High traffic

Monthly Cost: $200-300
```

### Scenario 4: Enterprise (100000+ users)
```
Configuration:
- 10-20 ECS tasks
- db.r5.large (Multi-AZ)
- Very high traffic
- Additional caching (ElastiCache)

Monthly Cost: $500-1000+
```

---

## 🎯 Cost Monitoring

### Set Up Billing Alerts

```powershell
# Create billing alarm
aws cloudwatch put-metric-alarm `
    --alarm-name "MonthlyBillingAlert" `
    --alarm-description "Alert when monthly bill exceeds $100" `
    --metric-name EstimatedCharges `
    --namespace AWS/Billing `
    --statistic Maximum `
    --period 21600 `
    --evaluation-periods 1 `
    --threshold 100 `
    --comparison-operator GreaterThanThreshold
```

### Use AWS Cost Explorer

1. Go to AWS Console → Billing → Cost Explorer
2. Enable Cost Explorer (free)
3. Create custom reports:
   - Daily costs by service
   - Monthly cost trends
   - Cost by tag (Environment, Project)

### Tag Resources for Cost Tracking

All resources are automatically tagged:
```hcl
tags = {
  Project     = "singha-loyalty"
  Environment = "production"
  ManagedBy   = "Terraform"
}
```

---

## 📊 Cost Comparison

### vs. Traditional EC2

```
Traditional Setup:
- 2 × t3.small EC2 instances: $30/month
- RDS db.t3.small: $56/month
- ALB: $20/month
Total: ~$106/month

Fargate Setup (This Infrastructure):
- ECS Fargate (2 tasks): $7/month
- RDS db.t3.small: $56/month
- ALB: $20/month
Total: ~$83/month

Savings: $23/month (22%)
```

### vs. Serverless (Lambda)

```
Lambda Setup:
- Lambda invocations: $20/month
- API Gateway: $35/month
- RDS Proxy: $15/month
- RDS: $56/month
Total: ~$126/month

Fargate Setup: ~$83/month

Savings: $43/month (34%)
```

---

## 🔍 Hidden Costs to Watch

### 1. Data Transfer
```
Inter-AZ Transfer: $0.01/GB
Internet Transfer: $0.09/GB (after 1 GB free)

Tip: Keep ECS tasks and RDS in same AZ when possible
```

### 2. CloudWatch Metrics
```
Custom Metrics: $0.30/metric/month
API Calls: $0.01/1000 calls

Tip: Use Container Insights only in production
```

### 3. Secrets Manager API Calls
```
First 10,000 calls: Free
Additional: $0.05/10,000 calls

Tip: Cache secrets in application
```

### 4. ECR Data Transfer
```
To ECS in same region: Free
To internet: $0.09/GB

Tip: Always deploy in same region
```

---

## 💰 Free Tier Benefits

### First 12 Months (New AWS Accounts)

```
✅ RDS: 750 hours/month of db.t2.micro (not t3.micro)
✅ ALB: 750 hours/month
✅ CloudWatch: 10 custom metrics
✅ S3: 5 GB storage
✅ CloudFront: 50 GB data transfer
✅ ECR: 500 MB storage

Potential Savings: $50-70/month for first year
```

### Always Free

```
✅ CloudWatch: 5 GB log ingestion
✅ Lambda: 1M requests/month (if used)
✅ DynamoDB: 25 GB storage (if used)
```

---

## 📝 Cost Optimization Checklist

- [ ] Enable Fargate Spot (70% savings)
- [ ] Right-size RDS instance
- [ ] Set up auto-scaling for ECS
- [ ] Reduce CloudWatch log retention
- [ ] Enable S3 lifecycle policies
- [ ] Disable Container Insights in dev
- [ ] Set up billing alerts
- [ ] Review costs monthly
- [ ] Tag all resources
- [ ] Use Cost Explorer
- [ ] Consider Reserved Capacity for production
- [ ] Optimize CloudFront cache settings
- [ ] Review and remove unused resources

---

## 🎓 Cost Management Best Practices

### 1. Regular Reviews
- Weekly: Check Cost Explorer
- Monthly: Review detailed billing
- Quarterly: Optimize resource allocation

### 2. Environment Separation
```
Development: Minimal resources, Spot instances
Staging: Similar to production, smaller scale
Production: Full resources, high availability
```

### 3. Automated Cleanup
```
# Delete old ECR images
# Remove old CloudWatch logs
# Clean up unused snapshots
```

### 4. Use Terraform for Cost Control
```hcl
# Prevent accidental expensive resources
validation {
  condition     = var.db_instance_class != "db.r5.large"
  error_message = "Use smaller instance for dev/staging"
}
```

---

## 📞 Need Help?

For cost optimization assistance:
1. Use AWS Cost Explorer
2. Enable AWS Trusted Advisor
3. Contact AWS Support
4. Consult with DevOps team

---

**Last Updated**: February 2026
**Pricing Region**: US East (N. Virginia)
**Note**: Prices are estimates and may vary by region and usage patterns
