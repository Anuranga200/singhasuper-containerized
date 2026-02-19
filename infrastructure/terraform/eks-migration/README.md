# EKS Migration Guide

## 🎯 Overview

This comprehensive guide enables you to temporarily migrate your backend application from Amazon ECS (Fargate) to Amazon EKS for exploration and learning purposes. The migration is designed to be:

- **Reversible**: Clean rollback to ECS without any impact
- **Modular**: EKS resources are completely isolated from ECS
- **Cost-Conscious**: Optimized for AWS free tier during one-week exploration
- **Production-Ready**: Follows AWS Well-Architected Framework best practices

**Use Cases:**
- Learn Kubernetes and EKS hands-on
- Compare ECS vs EKS performance and operational characteristics
- Evaluate EKS for future production workloads
- Understand cost implications before committing

---

## 📋 Table of Contents

### Getting Started
- [Quick Start (Terraform)](#quick-start-terraform) - Deploy in 30 minutes
- [Manual Deployment (Console)](#manual-deployment-console) - Step-by-step learning
- [Prerequisites](#prerequisites)

### Core Documentation
- [Cost Estimation](docs/COST_ESTIMATION.md) - Detailed cost breakdown ($18-25/week)
- [Terraform Deployment Guide](docs/TERRAFORM_DEPLOYMENT_GUIDE.md) - Complete automation guide
- [Manual Console Guide](docs/MANUAL_CONSOLE_GUIDE.md) - AWS Console step-by-step
- [Rollback Guide](docs/ROLLBACK_GUIDE.md) - Safe return to ECS

### Architecture & Design
- [Architecture Overview](docs/ARCHITECTURE.md) - System design and diagrams
- [Well-Architected Framework](docs/WELL_ARCHITECTED.md) - Best practices explained
- [Traffic Shifting Strategy](docs/TRAFFIC_SHIFTING.md) - Gradual migration approach

### Operations
- [Monitoring & Logging](docs/MONITORING.md) - CloudWatch setup and dashboards
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [Verification Commands](docs/VERIFICATION.md) - Health check procedures

### Reference
- [Module Documentation](#module-documentation)
- [Kubernetes Manifests](kubernetes-manifests/)
- [Project Structure](STRUCTURE.md)

---

## ⚡ Quick Start (Terraform)

**Time:** ~30 minutes | **Cost:** ~$18-25/week

### 1. Prerequisites Check

```bash
# Verify tools are installed
terraform version  # >= 1.0
aws --version      # >= 2.0
kubectl version --client  # >= 1.28
helm version       # >= 3.0

# Configure AWS credentials
aws configure
aws sts get-caller-identity
```

### 2. Configure Variables

```bash
cd environments/exploration
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

**Required values:**
- VPC ID and subnet IDs
- RDS endpoint and credentials
- ALB and ECS target group ARNs
- ECR image URI

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review plan
terraform plan

# Apply (creates EKS cluster, nodes, and Kubernetes resources)
terraform apply
```

**What gets created:**
- ✅ EKS cluster (10-12 min)
- ✅ 2 worker nodes (5-7 min)
- ✅ Kubernetes resources (namespace, deployment, service, ingress)
- ✅ ALB target group and weighted routing
- ✅ IAM roles and security groups
- ✅ CloudWatch log groups

### 4. Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name backend-eks-exploration
kubectl get nodes
kubectl get pods -n backend
```

### 5. Install AWS Load Balancer Controller

```bash
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=backend-eks-exploration \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$(terraform output -raw alb_controller_role_arn)
```

### 6. Verify Deployment

```bash
# Check pod health
kubectl get pods -n backend

# Check target group
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw eks_target_group_arn)

# Test endpoint (temporarily route 100% to EKS)
curl -I http://your-alb-dns/health
```

**✅ Deployment Complete!**

**Next Steps:**
1. Monitor for 1-2 hours with 0% traffic
2. Begin gradual traffic shifting (10% → 25% → 50% → 100%)
3. Compare ECS vs EKS metrics in CloudWatch
4. When done, follow [Rollback Guide](docs/ROLLBACK_GUIDE.md)

---

## 🖥️ Manual Deployment (Console)

**Time:** ~2.5-3 hours | **Best for:** Learning and understanding each component

See [Manual Console Guide](docs/MANUAL_CONSOLE_GUIDE.md) for detailed step-by-step instructions including:

1. **EKS Cluster Creation** (30-40 min)
   - IAM role setup
   - Cluster configuration
   - Networking setup

2. **Node Group Creation** (20-30 min)
   - IAM role for nodes
   - Instance configuration
   - Autoscaling setup

3. **kubectl Configuration** (10 min)
   - AWS CLI setup
   - Kubeconfig generation
   - Connection verification

4. **Application Deployment** (30-40 min)
   - Kubernetes manifests
   - Secrets configuration
   - Pod deployment

5. **ALB Integration** (20-30 min)
   - Target group creation
   - Listener rule configuration
   - Health check setup

6. **AWS Load Balancer Controller** (15-20 min)
   - Helm installation
   - IRSA configuration
   - Controller deployment

---

## 📊 Cost Estimation

### Weekly Cost Breakdown

| Component | Cost | Free Tier |
|-----------|------|-----------|
| EKS Control Plane | $16.80 | ❌ No |
| EC2 (2× t3.micro) | $0.00 | ✅ Yes (750 hrs/month) |
| EBS (40 GB) | $0.18 | ⚠️ Partial (30 GB free) |
| Data Transfer | $0.00 | ✅ Yes (100 GB/month) |
| CloudWatch | $1.04 | ⚠️ Partial |
| **Total** | **~$18.02** | |

**Cost Optimization Tips:**
- Use t3.micro instead of t3.small (saves $6.99/week)
- Limit exploration to 3-4 days (saves 40-50%)
- Use spot instances (saves up to 70% on EC2)
- Set billing alerts at $20 threshold

**Comparison:**
- ECS Fargate: $8.29/week
- EKS (optimized): $18.02/week
- **Difference:** +$9.73/week (+117%)

See [Cost Estimation Guide](docs/COST_ESTIMATION.md) for detailed breakdown.

---

## 🏗️ Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                    ┌────▼────┐
                    │   ALB   │
                    └────┬────┘
                         │
          ┌──────────────┴──────────────┐
          │                             │
     ┌────▼────┐                   ┌────▼────┐
     │   ECS   │                   │   EKS   │
     │ Target  │                   │ Target  │
     │  Group  │                   │  Group  │
     │Weight:  │                   │Weight:  │
     │ 100→0%  │                   │  0→100% │
     └────┬────┘                   └────┬────┘
          │                             │
     ┌────▼────┐                   ┌────▼────┐
     │ Fargate │                   │   EKS   │
     │  Tasks  │                   │  Pods   │
     └────┬────┘                   └────┬────┘
          │                             │
          └──────────────┬──────────────┘
                         │
                    ┌────▼────┐
                    │   RDS   │
                    │PostgreSQL│
                    └─────────┘
```

### Key Design Principles

1. **Isolation**: EKS and ECS run independently
2. **Reversibility**: Can rollback to ECS in < 30 seconds
3. **Shared Resources**: RDS, ECR, ALB, VPC reused
4. **Multi-AZ**: Nodes and pods distributed across AZs
5. **Security**: IAM roles, security groups, secrets management

See [Architecture Documentation](docs/ARCHITECTURE.md) for detailed diagrams.

---

## 📦 Module Documentation

### eks-cluster

Creates EKS control plane with IAM roles, security groups, and OIDC provider.

**Location:** `modules/eks-cluster/`

**Key Features:**
- Configurable Kubernetes version
- Public and private API endpoints
- CloudWatch logging enabled
- OIDC provider for IRSA

[Full Documentation](modules/eks-cluster/README.md)

### eks-node-group

Creates worker nodes with autoscaling and security configurations.

**Location:** `modules/eks-node-group/`

**Key Features:**
- Multi-AZ deployment
- Configurable instance types
- RDS security group access
- ECR pull permissions

[Full Documentation](modules/eks-node-group/README.md)

### kubernetes-resources

Deploys application resources to Kubernetes cluster.

**Location:** `modules/kubernetes-resources/`

**Key Features:**
- Namespace isolation
- Deployment with health checks
- Secrets management
- Pod disruption budgets
- Horizontal pod autoscaling

[Full Documentation](modules/kubernetes-resources/README.md)

### alb-integration

Configures ALB target group and weighted routing.

**Location:** `modules/alb-integration/`

**Key Features:**
- IP target type for direct pod routing
- Weighted traffic distribution
- Health check configuration
- Fast deregistration for rollback

[Full Documentation](modules/alb-integration/README.md)

### alb-controller-iam

Creates IAM role for AWS Load Balancer Controller using IRSA.

**Location:** `modules/alb-controller-iam/`

**Key Features:**
- OIDC-based authentication
- Least privilege permissions
- ALB/NLB management capabilities

[Full Documentation](modules/alb-controller-iam/README.md)

---

## 🔄 Traffic Shifting Strategy

### Phased Approach

| Phase | EKS % | ECS % | Duration | Actions |
|-------|-------|-------|----------|---------|
| **0. Validation** | 0% | 100% | 1-2 hrs | Verify pods healthy, check logs |
| **1. Canary** | 10% | 90% | 2-4 hrs | Monitor errors, compare metrics |
| **2. Gradual** | 25% | 75% | 2 hrs | Increase monitoring |
| **3. Gradual** | 50% | 50% | 2 hrs | Equal split testing |
| **4. Gradual** | 75% | 25% | 2 hrs | Majority on EKS |
| **5. Full** | 100% | 0% | 24-48 hrs | Complete migration |

### Monitoring Checklist

Between each phase, verify:
- ✅ Target health (all targets healthy)
- ✅ Error rates (< 1% 5XX errors)
- ✅ Response times (p95 < 500ms)
- ✅ Pod status (all running)
- ✅ Database connections (no errors)
- ✅ Application logs (no critical errors)

### Rollback

If issues detected at any phase:

```bash
# Immediate rollback to ECS
terraform apply -var="eks_weight=0" -var="ecs_weight=100" -target=module.alb_integration

# Or via AWS CLI
aws elbv2 modify-listener --listener-arn $LISTENER_ARN \
  --default-actions Type=forward,ForwardConfig='{
    "TargetGroups":[
      {"TargetGroupArn":"'$ECS_TG_ARN'","Weight":100}
    ]
  }'
```

**Rollback time:** < 30 seconds

---

## 🛠️ Troubleshooting

### Common Issues

**Pods not starting:**
```bash
kubectl describe pod <pod-name> -n backend
# Check: ImagePullBackOff, CrashLoopBackOff, Pending
```

**Database connection fails:**
```bash
# Test from pod
kubectl exec -it <pod-name> -n backend -- nc -zv <db-host> 5432
# Verify: Security group rules, DNS resolution
```

**ALB not routing to EKS:**
```bash
# Check target health
aws elbv2 describe-target-health --target-group-arn $EKS_TG_ARN
# Verify: Targets registered, health checks passing
```

**High costs:**
```bash
# Check current spend
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '7 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost
```

See [Troubleshooting Guide](docs/TROUBLESHOOTING.md) for comprehensive solutions.

---

## 🔙 Rollback to ECS

When exploration is complete, safely return to ECS:

### Quick Rollback

```bash
# 1. Shift all traffic to ECS
terraform apply -var="eks_weight=0" -var="ecs_weight=100"

# 2. Verify ECS handling 100% traffic
aws elbv2 describe-target-health --target-group-arn $ECS_TG_ARN

# 3. Destroy EKS infrastructure
terraform destroy

# 4. Verify cleanup
aws eks list-clusters
aws ec2 describe-instances --filters "Name=tag:kubernetes.io/cluster/backend-eks-exploration,Values=owned"
```

**Estimated time:** 40-50 minutes

See [Rollback Guide](docs/ROLLBACK_GUIDE.md) for detailed procedure.

---

## 📚 Additional Resources

### AWS Documentation
- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)

### Kubernetes Documentation
- [Kubernetes Concepts](https://kubernetes.io/docs/concepts/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)

### Terraform Documentation
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)

### Cost Optimization
- [AWS Pricing Calculator](https://calculator.aws/)
- [EKS Cost Optimization](https://aws.amazon.com/blogs/containers/cost-optimization-for-kubernetes-on-aws/)

---

## 🤝 Support

### Getting Help

1. **Check Documentation**: Review relevant guides in `docs/`
2. **Troubleshooting**: See [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
3. **Verification**: Run commands from [Verification Guide](docs/VERIFICATION.md)
4. **AWS Support**: Contact AWS Support for infrastructure issues

### Reporting Issues

When reporting issues, include:
- Terraform version and AWS CLI version
- Error messages and logs
- Output of `kubectl get pods -n backend`
- Output of `terraform plan`

---

## ⚠️ Important Notes

### Before You Begin

- ✅ This is designed for **temporary exploration** (1 week)
- ✅ EKS costs **2-3x more** than ECS Fargate for this workload
- ✅ Set up **billing alerts** before deployment
- ✅ Plan to **rollback to ECS** after testing
- ✅ **Do not** use for production without proper planning

### Security Considerations

- 🔒 Store secrets in AWS Secrets Manager (not in code)
- 🔒 Use IAM roles (not access keys) for authentication
- 🔒 Enable VPC flow logs for network monitoring
- 🔒 Regularly update Kubernetes version
- 🔒 Implement pod security policies

### Cost Management

- 💰 Monitor costs daily during exploration
- 💰 Destroy resources promptly when done
- 💰 Use t3.micro instances for free tier
- 💰 Consider spot instances for non-production
- 💰 Set billing alerts at $20 threshold

---

## 📝 License

This guide is provided as-is for educational and exploration purposes.

---

## 🎓 Learning Outcomes

After completing this guide, you will understand:

✅ How to deploy and manage EKS clusters  
✅ Kubernetes core concepts (pods, deployments, services, ingress)  
✅ AWS Load Balancer Controller and Ingress configuration  
✅ IAM Roles for Service Accounts (IRSA)  
✅ Multi-AZ deployment and high availability patterns  
✅ Traffic shifting and blue-green deployment strategies  
✅ CloudWatch monitoring and logging for Kubernetes  
✅ Cost comparison between ECS and EKS  
✅ When to use EKS vs ECS Fargate  

**Ready to get started?** → [Quick Start](#quick-start-terraform)

---

**Last Updated:** February 2026  
**Version:** 1.0.0  
**Terraform Version:** >= 1.0  
**Kubernetes Version:** 1.28
