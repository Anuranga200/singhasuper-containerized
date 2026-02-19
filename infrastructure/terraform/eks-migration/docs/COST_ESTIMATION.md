# EKS Migration Cost Estimation

## Overview

This document provides a detailed cost breakdown for running Amazon EKS for one week on an AWS free tier account. The analysis includes all associated costs and compares them with the existing ECS Fargate deployment.

**Estimation Date:** February 2026  
**Duration:** 7 days (168 hours)  
**Region:** US East (N. Virginia) - us-east-1  
**Account Type:** AWS Free Tier

---

## Cost Summary

| Service | Weekly Cost | Free Tier Eligible | Notes |
|---------|-------------|-------------------|-------|
| **EKS Control Plane** | **$16.80** | ❌ No | $0.10/hour × 168 hours |
| **EC2 Instances (2× t3.small)** | **$6.94** | ⚠️ Partial | 750 hours/month free tier |
| **EBS Volumes (2× 20GB gp3)** | **$0.32** | ✅ Yes | 30GB free tier |
| **Data Transfer** | **$0.50** | ⚠️ Partial | 100GB free tier |
| **NAT Gateway** | **$0.00** | N/A | Using existing NAT |
| **CloudWatch Logs** | **$0.25** | ⚠️ Partial | 5GB free tier |
| **CloudWatch Metrics** | **$0.00** | ✅ Yes | 10 custom metrics free |
| **ALB** | **$0.00** | N/A | Using existing ALB |
| **TOTAL (with free tier)** | **~$24.81** | | |
| **TOTAL (without free tier)** | **~$27.15** | | |

---

## Detailed Cost Breakdown

### 1. EKS Control Plane

**Cost:** $16.80/week

```
Hourly Rate: $0.10/hour
Weekly Cost: $0.10 × 168 hours = $16.80
Monthly Cost: $0.10 × 730 hours = $73.00
```

**Free Tier:** ❌ Not eligible

**Notes:**
- EKS control plane is charged per cluster per hour
- This is the largest cost component for EKS
- No free tier available for EKS control plane
- Cost is the same regardless of cluster size or usage

**Well-Architected Consideration:**
- *Cost Optimization*: This fixed cost makes EKS more expensive for small workloads compared to ECS Fargate

---

### 2. EC2 Worker Nodes

**Configuration:**
- Instance Type: 2× t3.small
- vCPUs: 2 per instance (4 total)
- Memory: 2 GB per instance (4 GB total)
- Availability Zones: 2 (multi-AZ deployment)

**Cost Calculation:**

```
t3.small On-Demand Rate: $0.0208/hour
Number of Instances: 2
Hourly Cost: $0.0208 × 2 = $0.0416/hour
Weekly Cost: $0.0416 × 168 hours = $6.99/week
```

**Free Tier Application:**
- Free Tier: 750 hours/month of t2.micro or t3.micro
- t3.small is NOT directly covered by free tier
- However, if using t3.micro instead:
  - 2 instances × 168 hours = 336 hours/week
  - 336 hours < 750 hours free tier
  - **Cost with t3.micro: $0.00/week** (fully covered)

**Cost with Free Tier (t3.small):** $6.94/week  
**Cost with Free Tier (t3.micro):** $0.00/week  
**Cost without Free Tier:** $6.99/week

**Alternative: t3.micro**

```
t3.micro On-Demand Rate: $0.0104/hour
Number of Instances: 2
Hourly Cost: $0.0104 × 2 = $0.0208/hour
Weekly Cost: $0.0208 × 168 hours = $3.49/week
With Free Tier: $0.00/week (336 hours < 750 hours)
```

**Recommendation:**
- For cost optimization during exploration, use **t3.micro** instances
- Trade-off: Less CPU/memory per node (1 vCPU, 1 GB RAM)
- Sufficient for testing with 2 backend pods

---

### 3. EBS Storage

**Configuration:**
- Volume Type: gp3 (General Purpose SSD)
- Size: 20 GB per node
- Total: 40 GB (2 nodes)

**Cost Calculation:**

```
gp3 Rate: $0.08/GB-month
Monthly Cost: $0.08 × 40 GB = $3.20/month
Weekly Cost: $3.20 / 4.33 = $0.74/week
```

**Free Tier Application:**
- Free Tier: 30 GB of gp2 or gp3 storage
- Usage: 40 GB
- Billable: 40 GB - 30 GB = 10 GB
- **Cost with Free Tier: $0.08 × 10 GB / 4.33 = $0.18/week**

**Cost with Free Tier:** $0.18/week  
**Cost without Free Tier:** $0.74/week

---

### 4. Data Transfer

**Estimated Traffic:**
- ALB to EKS: 10 GB/week (internal, no charge)
- Internet egress: 5 GB/week (application responses)
- Inter-AZ: 2 GB/week

**Cost Calculation:**

```
Data Transfer Out (Internet): $0.09/GB
Internet Egress: 5 GB × $0.09 = $0.45/week

Inter-AZ Transfer: $0.01/GB
Inter-AZ: 2 GB × $0.01 = $0.02/week

Total: $0.47/week
```

**Free Tier Application:**
- Free Tier: 100 GB data transfer out per month
- Usage: ~20 GB/month
- **Cost with Free Tier: $0.00/week**

**Cost with Free Tier:** $0.00/week  
**Cost without Free Tier:** $0.47/week

---

### 5. NAT Gateway

**Cost:** $0.00 (using existing NAT Gateway)

**Notes:**
- NAT Gateway already exists for ECS deployment
- No incremental cost for EKS usage
- If creating new NAT Gateway:
  - Hourly Rate: $0.045/hour
  - Data Processing: $0.045/GB
  - Weekly Cost: ~$7.56 + data processing

**Well-Architected Consideration:**
- *Cost Optimization*: Reusing existing NAT Gateway saves ~$30/month

---

### 6. CloudWatch Logs

**Estimated Log Volume:**
- Application Logs: 2 GB/week
- Container Insights: 1 GB/week
- Control Plane Logs: 0.5 GB/week
- Total: 3.5 GB/week

**Cost Calculation:**

```
Log Ingestion: $0.50/GB
Ingestion Cost: 3.5 GB × $0.50 = $1.75/week

Log Storage: $0.03/GB-month
Storage Cost: 3.5 GB × $0.03 / 4.33 = $0.02/week

Total: $1.77/week
```

**Free Tier Application:**
- Free Tier: 5 GB ingestion per month
- Usage: ~14 GB/month
- Billable: 14 GB - 5 GB = 9 GB
- **Cost with Free Tier: 9 GB × $0.50 / 4.33 = $1.04/week**

**Cost with Free Tier:** $1.04/week  
**Cost without Free Tier:** $1.77/week

---

### 7. CloudWatch Metrics

**Estimated Metrics:**
- Container Insights: 7 custom metrics
- Application Metrics: 3 custom metrics
- Total: 10 custom metrics

**Cost Calculation:**

```
Custom Metrics: $0.30/metric-month
Monthly Cost: 10 × $0.30 = $3.00/month
Weekly Cost: $3.00 / 4.33 = $0.69/week
```

**Free Tier Application:**
- Free Tier: 10 custom metrics
- Usage: 10 metrics
- **Cost with Free Tier: $0.00/week**

**Cost with Free Tier:** $0.00/week  
**Cost without Free Tier:** $0.69/week

---

### 8. Application Load Balancer

**Cost:** $0.00 (using existing ALB)

**Notes:**
- ALB already exists for ECS deployment
- Only creating new target group (no additional ALB cost)
- If creating new ALB:
  - Hourly Rate: $0.0225/hour
  - LCU Rate: $0.008/LCU-hour
  - Weekly Cost: ~$3.78 + LCU charges

---

## Cost Comparison: ECS Fargate vs EKS

### ECS Fargate (Current)

**Configuration:**
- 2 tasks (0.5 vCPU, 1 GB RAM each)
- Running 24/7

**Cost Calculation:**

```
Fargate vCPU: $0.04048/vCPU-hour
Fargate Memory: $0.004445/GB-hour

Per Task:
- vCPU: 0.5 × $0.04048 = $0.02024/hour
- Memory: 1 GB × $0.004445 = $0.004445/hour
- Total: $0.024685/hour

2 Tasks:
- Hourly: $0.024685 × 2 = $0.04937/hour
- Weekly: $0.04937 × 168 = $8.29/week
- Monthly: $0.04937 × 730 = $36.04/month
```

**ECS Fargate Weekly Cost:** $8.29

### EKS (Proposed)

**Configuration Option 1: t3.small nodes**
- Weekly Cost: $24.81 (with free tier)

**Configuration Option 2: t3.micro nodes**
- Weekly Cost: $18.02 (with free tier)

### Cost Comparison Table

| Deployment | Weekly Cost | Monthly Cost | Difference |
|------------|-------------|--------------|------------|
| **ECS Fargate** | $8.29 | $36.04 | Baseline |
| **EKS (t3.small)** | $24.81 | $107.84 | +$71.80/month (+199%) |
| **EKS (t3.micro)** | $18.02 | $78.34 | +$42.30/month (+117%) |

**Key Insights:**

1. **EKS is more expensive** for small workloads due to fixed control plane cost
2. **ECS Fargate is more cost-effective** for this use case
3. **EKS becomes competitive** at larger scales (10+ tasks)
4. **Free tier helps** but doesn't eliminate the cost difference

---

## Cost Optimization Strategies

### 1. Use t3.micro Instead of t3.small

**Savings:** $6.99/week → $0.00/week (with free tier)

**Trade-offs:**
- Less CPU: 1 vCPU vs 2 vCPU per node
- Less memory: 1 GB vs 2 GB per node
- Still sufficient for 2 backend pods

**Recommendation:** ✅ Use t3.micro for exploration

---

### 2. Reduce Node Count to 1

**Savings:** $3.49/week (50% reduction)

**Trade-offs:**
- ❌ No high availability
- ❌ Single point of failure
- ❌ Not recommended even for testing

**Recommendation:** ❌ Keep 2 nodes for reliability

---

### 3. Reduce Log Retention

**Savings:** $0.50/week

**Configuration:**
- Change retention from 7 days to 1 day
- Reduces storage costs

**Recommendation:** ✅ Use 3-day retention for exploration

---

### 4. Disable Container Insights

**Savings:** $1.04/week

**Trade-offs:**
- ❌ No detailed metrics
- ❌ Harder to troubleshoot
- ❌ Can't compare ECS vs EKS performance

**Recommendation:** ❌ Keep enabled for comparison

---

### 5. Use Spot Instances

**Savings:** Up to 70% on EC2 costs

**Configuration:**
- Change capacity_type from "ON_DEMAND" to "SPOT"
- Potential savings: $4.89/week

**Trade-offs:**
- ⚠️ Instances can be interrupted
- ⚠️ Not suitable for production
- ✅ Acceptable for short-term exploration

**Recommendation:** ⚠️ Consider for cost-sensitive exploration

---

### 6. Limit Exploration Duration

**Savings:** Proportional to time

**Recommendation:**
- Test for 3-4 days instead of full week
- Savings: ~40-50% of total cost
- Still sufficient for evaluation

---

## Minimum Cost Configuration

**Optimized Setup:**
- Instance Type: 2× t3.micro (free tier)
- Log Retention: 3 days
- Capacity Type: SPOT (optional)
- Duration: 4 days

**Estimated Cost:**

```
EKS Control Plane: $0.10 × 96 hours = $9.60
EC2 (t3.micro SPOT): $0.00 (free tier + spot discount)
EBS: $0.10 (reduced duration)
Data Transfer: $0.00 (free tier)
CloudWatch Logs: $0.60 (reduced retention)
CloudWatch Metrics: $0.00 (free tier)

Total: ~$10.30 for 4 days
```

**Minimum Weekly Cost:** ~$10.30 (4-day exploration)  
**Minimum Full Week Cost:** ~$18.02 (t3.micro, optimized settings)

---

## Billing Alerts Setup

### AWS Budgets Configuration

**Create a budget to avoid unexpected charges:**

```bash
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget file://budget.json \
  --notifications-with-subscribers file://notifications.json
```

**budget.json:**

```json
{
  "BudgetName": "EKS-Exploration-Budget",
  "BudgetLimit": {
    "Amount": "30",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST",
  "CostFilters": {
    "TagKeyValue": ["user:Purpose$eks-migration"]
  }
}
```

**notifications.json:**

```json
[
  {
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 80,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [
      {
        "SubscriptionType": "EMAIL",
        "Address": "your-email@example.com"
      }
    ]
  },
  {
    "Notification": {
      "NotificationType": "FORECASTED",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 100,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [
      {
        "SubscriptionType": "EMAIL",
        "Address": "your-email@example.com"
      }
    ]
  }
]
```

### CloudWatch Billing Alarm

**Create an alarm for total estimated charges:**

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name eks-exploration-billing-alarm \
  --alarm-description "Alert when estimated charges exceed $25" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 21600 \
  --evaluation-periods 1 \
  --threshold 25 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=Currency,Value=USD \
  --alarm-actions arn:aws:sns:us-east-1:ACCOUNT_ID:billing-alerts
```

---

## Cost Monitoring During Exploration

### Daily Cost Checks

**View current month-to-date costs:**

```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '1 day ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

### Cost Explorer Filters

**Filter by EKS-related services:**
- Amazon Elastic Kubernetes Service
- Amazon EC2
- Amazon EBS
- Amazon CloudWatch

**Use tags for tracking:**
- Add tag: `Purpose=eks-migration`
- Filter Cost Explorer by this tag

---

## Conclusion

### Key Takeaways

1. **Expected Weekly Cost:** $18-25 with free tier optimizations
2. **EKS is 2-3x more expensive** than ECS Fargate for this workload
3. **Control plane cost ($16.80/week)** is the largest component
4. **Free tier helps** but doesn't eliminate the cost difference
5. **Optimization strategies** can reduce costs by 20-30%

### Recommendations

✅ **For Exploration:**
- Use t3.micro instances (free tier eligible)
- Limit exploration to 3-4 days
- Enable billing alerts at $20 threshold
- Use spot instances if comfortable with interruptions

✅ **For Production:**
- EKS is cost-effective at scale (10+ pods)
- Consider Reserved Instances for 30-40% savings
- Use Cluster Autoscaler to optimize node count
- Implement pod right-sizing to maximize node utilization

❌ **Not Recommended:**
- Running EKS long-term for small workloads
- Disabling monitoring to save costs
- Using single-node clusters

### Next Steps

1. Set up billing alerts before deployment
2. Monitor costs daily during exploration
3. Document actual costs vs estimates
4. Clean up resources promptly after testing
5. Return to ECS Fargate for production

---

## Additional Resources

- [AWS Pricing Calculator](https://calculator.aws/)
- [EKS Pricing](https://aws.amazon.com/eks/pricing/)
- [EC2 Pricing](https://aws.amazon.com/ec2/pricing/)
- [AWS Free Tier](https://aws.amazon.com/free/)
- [Cost Optimization Best Practices](https://aws.amazon.com/architecture/cost-optimization/)
