# Terraform Deployment Guide

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Traffic Shifting Procedure](#traffic-shifting-procedure)
4. [Module Usage](#module-usage)
5. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

| Tool | Minimum Version | Installation |
|------|----------------|--------------|
| **Terraform** | >= 1.0 | [Download](https://www.terraform.io/downloads) |
| **AWS CLI** | >= 2.0 | [Download](https://aws.amazon.com/cli/) |
| **kubectl** | >= 1.28 | [Download](https://kubernetes.io/docs/tasks/tools/) |
| **Helm** | >= 3.0 | [Download](https://helm.sh/docs/intro/install/) |

### AWS Credentials Configuration

```bash
# Configure AWS CLI with your credentials
aws configure

# Verify credentials
aws sts get-caller-identity

# Expected output:
# {
#     "UserId": "AIDAXXXXXXXXXXXXXXXXX",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/your-username"
# }
```

### Required AWS Permissions

Your IAM user/role must have permissions for:
- EKS (create/manage clusters and node groups)
- EC2 (create/manage instances, security groups, network interfaces)
- IAM (create/manage roles and policies)
- ELB (create/manage target groups and listener rules)
- CloudWatch (create/manage log groups and alarms)
- ECR (read access to pull images)

### VPC and Subnet Requirements

- Existing VPC with private subnets in at least 2 availability zones
- Subnets must have available IP addresses for EKS nodes
- NAT Gateway configured for internet access from private subnets
- Existing RDS database in the same VPC
- Existing ALB with listener configured

---

## Quick Start

### Step 1: Clone and Navigate

```bash
cd infrastructure/terraform/eks-migration/environments/exploration
```

### Step 2: Configure Variables

Copy the example variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
# AWS Configuration
aws_region = "us-east-1"
vpc_id     = "vpc-xxxxx"  # Your VPC ID
subnet_ids = [
  "subnet-xxxxx",  # Private subnet AZ1
  "subnet-xxxxx"   # Private subnet AZ2
]

# EKS Cluster Configuration
cluster_name       = "backend-eks-exploration"
kubernetes_version = "1.28"

# Node Group Configuration
node_group_name = "backend-nodes"
instance_types  = ["t3.micro"]  # Use t3.micro for free tier
desired_size    = 2
min_size        = 2
max_size        = 3

# Application Configuration
container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/backend:latest"
replicas        = 2

# Database Configuration (from existing RDS)
db_host     = "backend-db.xxxxx.us-east-1.rds.amazonaws.com"
db_name     = "backend_production"
db_user     = "backend_user"
db_password = "your-secure-password"  # Use AWS Secrets Manager in production
jwt_secret  = "your-jwt-secret"

# ALB Configuration (from existing setup)
alb_arn                = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/backend-alb/xxxxx"
alb_listener_arn       = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/backend-alb/xxxxx/xxxxx"
ecs_target_group_arn   = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/ecs-backend/xxxxx"
rds_security_group_id  = "sg-xxxxx"

# Traffic Routing (start with 0% to EKS)
eks_weight = 0
ecs_weight = 100
```

### Step 3: Initialize Terraform

```bash
terraform init
```

**Expected output:**
```
Initializing modules...
Initializing the backend...
Initializing provider plugins...
Terraform has been successfully initialized!
```

### Step 4: Review the Plan

```bash
terraform plan
```

**Review the output carefully:**
- Verify resource counts
- Check that no existing resources will be destroyed
- Confirm all configurations match your requirements

**Expected resources to be created:**
- 1 EKS cluster
- 1 EKS node group
- 4-5 IAM roles and policies
- 3-4 security groups
- 1 ALB target group
- 1 ALB listener rule
- Kubernetes resources (namespace, deployment, service, ingress, secrets)

### Step 5: Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted.

**Estimated time:** 15-20 minutes
- EKS cluster creation: 10-12 minutes
- Node group creation: 5-7 minutes
- Kubernetes resources: 1-2 minutes

### Step 6: Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name backend-eks-exploration

# Verify connection
kubectl get nodes

# Expected output:
# NAME                         STATUS   ROLES    AGE   VERSION
# ip-10-0-1-100.ec2.internal   Ready    <none>   5m    v1.28.x
# ip-10-0-2-100.ec2.internal   Ready    <none>   5m    v1.28.x
```

### Step 7: Install AWS Load Balancer Controller

```bash
# Add Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Get the IAM role ARN from Terraform outputs
ALB_ROLE_ARN=$(terraform output -raw alb_controller_role_arn)

# Install the controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=backend-eks-exploration \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$ALB_ROLE_ARN

# Verify installation
kubectl get deployment -n kube-system aws-load-balancer-controller

# Expected output:
# NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
# aws-load-balancer-controller   2/2     2            2           1m
```

### Step 8: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n backend

# Expected output:
# NAME                           READY   STATUS    RESTARTS   AGE
# backend-api-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
# backend-api-xxxxxxxxxx-xxxxx   1/1     Running   0          2m

# Check service
kubectl get svc -n backend

# Check ingress
kubectl get ingress -n backend

# Check target group registration
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw eks_target_group_arn)

# Expected: 2 healthy targets (pod IPs)
```

### Step 9: Test Application

```bash
# Get the EKS target group ARN
TG_ARN=$(terraform output -raw eks_target_group_arn)

# Temporarily set EKS weight to 100 for testing
# (We'll do gradual shifting later)
aws elbv2 modify-listener \
  --listener-arn $(terraform output -raw alb_listener_arn) \
  --default-actions Type=forward,ForwardConfig='{
    "TargetGroups":[
      {"TargetGroupArn":"'$TG_ARN'","Weight":100}
    ]
  }'

# Test the endpoint
curl -I http://your-alb-dns-name/health

# Expected: HTTP/1.1 200 OK

# Reset to 0% EKS traffic
# (See Traffic Shifting section for gradual migration)
```

**Deployment Complete!** ✅

**Total Time:** ~25-30 minutes

---

## Traffic Shifting Procedure

### Overview

Traffic shifting allows you to gradually migrate traffic from ECS to EKS, enabling safe testing and instant rollback if issues arise.

### Phased Approach

**Phase 1: Validation (0% EKS)**
- Duration: 1-2 hours
- Verify all pods are healthy
- Check logs for errors
- Test database connectivity

**Phase 2: Canary (10% EKS)**
- Duration: 2-4 hours
- Monitor error rates
- Compare ECS vs EKS metrics
- Verify no issues with small traffic

**Phase 3: Gradual Increase (25% → 50% → 75%)**
- Duration: 4-8 hours
- Increase in 25% increments
- Monitor at each step
- Wait 1-2 hours between increases

**Phase 4: Full Migration (100% EKS)**
- Duration: Ongoing
- All traffic to EKS
- ECS remains as fallback
- Monitor for 24-48 hours

### Method 1: Terraform (Recommended)

**Update terraform.tfvars:**

```hcl
# Phase 2: Canary
eks_weight = 10
ecs_weight = 90
```

**Apply changes:**

```bash
terraform apply -target=module.alb_integration

# Verify
aws elbv2 describe-rules \
  --listener-arn $(terraform output -raw alb_listener_arn) \
  --query 'Rules[?Priority==`100`].Actions[0].ForwardConfig.TargetGroups'
```

**Repeat for each phase:**
- Phase 3a: eks_weight=25, ecs_weight=75
- Phase 3b: eks_weight=50, ecs_weight=50
- Phase 3c: eks_weight=75, ecs_weight=25
- Phase 4: eks_weight=100, ecs_weight=0

### Method 2: AWS CLI

```bash
# Get ARNs
ECS_TG_ARN=$(terraform output -raw ecs_target_group_arn)
EKS_TG_ARN=$(terraform output -raw eks_target_group_arn)
LISTENER_ARN=$(terraform output -raw alb_listener_arn)

# Phase 2: 10% EKS
aws elbv2 modify-listener \
  --listener-arn $LISTENER_ARN \
  --default-actions Type=forward,ForwardConfig='{
    "TargetGroups":[
      {"TargetGroupArn":"'$ECS_TG_ARN'","Weight":90},
      {"TargetGroupArn":"'$EKS_TG_ARN'","Weight":10}
    ]
  }'

# Phase 3a: 25% EKS
aws elbv2 modify-listener \
  --listener-arn $LISTENER_ARN \
  --default-actions Type=forward,ForwardConfig='{
    "TargetGroups":[
      {"TargetGroupArn":"'$ECS_TG_ARN'","Weight":75},
      {"TargetGroupArn":"'$EKS_TG_ARN'","Weight":25}
    ]
  }'

# Continue for other phases...
```

### Monitoring Between Phases

**Check target health:**

```bash
# ECS targets
aws elbv2 describe-target-health --target-group-arn $ECS_TG_ARN

# EKS targets
aws elbv2 describe-target-health --target-group-arn $EKS_TG_ARN
```

**Check CloudWatch metrics:**

```bash
# Open CloudWatch dashboard
aws cloudwatch get-dashboard \
  --dashboard-name EKS-Migration-Dashboard
```

**Check application logs:**

```bash
# EKS logs
kubectl logs -n backend -l app=backend-api --tail=100

# ECS logs (via CloudWatch)
aws logs tail /ecs/backend-service --follow
```

**Key metrics to monitor:**
- Request count per target group
- Response time (p50, p95, p99)
- Error rates (4XX, 5XX)
- Target health status
- CPU and memory utilization

### Rollback Procedure

**If issues are detected, immediately rollback:**

```bash
# Method 1: Terraform
# Edit terraform.tfvars
eks_weight = 0
ecs_weight = 100

terraform apply -target=module.alb_integration

# Method 2: AWS CLI
aws elbv2 modify-listener \
  --listener-arn $LISTENER_ARN \
  --default-actions Type=forward,ForwardConfig='{
    "TargetGroups":[
      {"TargetGroupArn":"'$ECS_TG_ARN'","Weight":100},
      {"TargetGroupArn":"'$EKS_TG_ARN'","Weight":0}
    ]
  }'

# Verify rollback
aws elbv2 describe-target-health --target-group-arn $ECS_TG_ARN
```

**Rollback time:** < 30 seconds

---

## Module Usage

### eks-cluster Module

**Purpose:** Creates EKS control plane with IAM roles and OIDC provider

**Inputs:**
- `cluster_name`: Name of the EKS cluster
- `kubernetes_version`: Kubernetes version (e.g., "1.28")
- `vpc_id`: VPC ID where cluster will be created
- `subnet_ids`: List of subnet IDs for cluster
- `endpoint_public_access`: Enable public API endpoint (default: true)
- `endpoint_private_access`: Enable private API endpoint (default: true)

**Outputs:**
- `cluster_id`: EKS cluster ID
- `cluster_endpoint`: API server endpoint
- `cluster_certificate_authority_data`: CA certificate for kubectl
- `oidc_provider_arn`: OIDC provider ARN for IRSA

**Example:**

```hcl
module "eks_cluster" {
  source = "../../modules/eks-cluster"
  
  cluster_name       = "my-cluster"
  kubernetes_version = "1.28"
  vpc_id             = "vpc-xxxxx"
  subnet_ids         = ["subnet-xxxxx", "subnet-xxxxx"]
  
  tags = {
    Environment = "production"
  }
}
```

### eks-node-group Module

**Purpose:** Creates worker nodes with autoscaling and security groups

**Inputs:**
- `cluster_name`: Name of the EKS cluster
- `node_group_name`: Name for the node group
- `subnet_ids`: List of subnet IDs for nodes
- `instance_types`: List of instance types (e.g., ["t3.small"])
- `desired_size`: Desired number of nodes
- `min_size`: Minimum number of nodes
- `max_size`: Maximum number of nodes
- `rds_security_group_id`: Security group ID of RDS for access

**Outputs:**
- `node_group_id`: Node group ID
- `node_security_group_id`: Security group ID for nodes
- `node_iam_role_arn`: IAM role ARN for nodes

**Example:**

```hcl
module "eks_node_group" {
  source = "../../modules/eks-node-group"
  
  cluster_name        = module.eks_cluster.cluster_id
  node_group_name     = "backend-nodes"
  subnet_ids          = ["subnet-xxxxx", "subnet-xxxxx"]
  instance_types      = ["t3.micro"]
  desired_size        = 2
  min_size            = 2
  max_size            = 3
  rds_security_group_id = "sg-xxxxx"
}
```

### kubernetes-resources Module

**Purpose:** Deploys application resources to Kubernetes

**Inputs:**
- `cluster_endpoint`: EKS cluster endpoint
- `cluster_ca_certificate`: Cluster CA certificate
- `container_image`: ECR image URI
- `replicas`: Number of pod replicas
- `db_host`, `db_name`, `db_user`, `db_password`: Database credentials
- `jwt_secret`: JWT secret for application

**Outputs:**
- `namespace`: Kubernetes namespace name
- `deployment_name`: Deployment name
- `service_name`: Service name

**Example:**

```hcl
module "kubernetes_resources" {
  source = "../../modules/kubernetes-resources"
  
  cluster_endpoint       = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = module.eks_cluster.cluster_certificate_authority_data
  container_image        = "123456789012.dkr.ecr.us-east-1.amazonaws.com/backend:latest"
  replicas               = 2
  
  db_host     = "db.example.com"
  db_name     = "mydb"
  db_user     = "user"
  db_password = "password"
  jwt_secret  = "secret"
}
```

### alb-integration Module

**Purpose:** Creates target group and configures weighted routing

**Inputs:**
- `alb_arn`: ARN of existing ALB
- `alb_listener_arn`: ARN of ALB listener
- `vpc_id`: VPC ID
- `ecs_target_group_arn`: ARN of ECS target group
- `eks_weight`: Traffic weight for EKS (0-100)
- `ecs_weight`: Traffic weight for ECS (0-100)

**Outputs:**
- `eks_target_group_arn`: ARN of EKS target group
- `listener_rule_arn`: ARN of weighted listener rule

**Example:**

```hcl
module "alb_integration" {
  source = "../../modules/alb-integration"
  
  alb_arn              = "arn:aws:elasticloadbalancing:..."
  alb_listener_arn     = "arn:aws:elasticloadbalancing:..."
  vpc_id               = "vpc-xxxxx"
  ecs_target_group_arn = "arn:aws:elasticloadbalancing:..."
  eks_weight           = 0
  ecs_weight           = 100
}
```

---

## Troubleshooting

### Issue: Terraform Init Fails

**Error:** "Failed to install provider"

**Solution:**
```bash
# Clear Terraform cache
rm -rf .terraform .terraform.lock.hcl

# Re-initialize
terraform init
```

### Issue: EKS Cluster Creation Fails

**Error:** "Error creating EKS Cluster: InvalidParameterException"

**Solution:**
- Verify subnet IDs are correct and in the same VPC
- Ensure subnets have available IP addresses
- Check IAM permissions for EKS service

### Issue: Nodes Not Joining Cluster

**Error:** Nodes show "NotReady" status

**Solution:**
```bash
# Check node logs
kubectl describe node <node-name>

# Common causes:
# 1. Security group blocking communication
# 2. IAM role missing permissions
# 3. Subnet routing issues

# Verify security groups allow:
# - Nodes to cluster: TCP 443, 10250
# - Nodes to nodes: All traffic
```

### Issue: Pods Not Starting

**Error:** "ImagePullBackOff"

**Solution:**
```bash
# Check pod events
kubectl describe pod <pod-name> -n backend

# Verify ECR permissions
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.us-east-1.amazonaws.com

# Check node IAM role has ECR permissions
```

### Issue: Database Connection Fails

**Error:** "ECONNREFUSED" or "timeout"

**Solution:**
```bash
# Test connectivity from pod
kubectl exec -it <pod-name> -n backend -- /bin/sh
nc -zv <db-host> 5432

# Verify security group rules:
# RDS SG must allow inbound from node SG on port 5432
```

### Issue: ALB Not Routing to EKS

**Error:** 503 errors or no traffic to EKS

**Solution:**
```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw eks_target_group_arn)

# Verify ALB controller is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check ingress status
kubectl describe ingress backend-api -n backend
```

---

## Next Steps

1. ✅ Complete deployment
2. ✅ Verify all components are healthy
3. ⏭️ Proceed to [Traffic Shifting](#traffic-shifting-procedure)
4. ⏭️ Monitor using CloudWatch Dashboard
5. ⏭️ When testing complete, follow [Rollback Guide](ROLLBACK_GUIDE.md)

---

## Additional Resources

- [Terraform EKS Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
