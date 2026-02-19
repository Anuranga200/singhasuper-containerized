# Quick Start Guide - EKS Migration

This guide will help you deploy the EKS infrastructure quickly using Terraform.

## Prerequisites

Before you begin, ensure you have:

- [ ] Terraform >= 1.0 installed
- [ ] AWS CLI configured with appropriate credentials
- [ ] kubectl installed
- [ ] Existing AWS infrastructure:
  - [ ] VPC with private subnets (at least 2 AZs)
  - [ ] RDS PostgreSQL database
  - [ ] Application Load Balancer with listener
  - [ ] ECS service with target group
  - [ ] ECR repository with backend container image

## Step 1: Configure Backend (One-Time Setup)

If you haven't already, create the S3 bucket and DynamoDB table for Terraform state:

```bash
# Create S3 bucket for state
aws s3api create-bucket \
  --bucket your-terraform-state-bucket \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket your-terraform-state-bucket \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

Update `backend.tf` with your actual bucket and table names.

## Step 2: Configure Variables

1. Copy the example variables file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your actual values:
   ```bash
   # Use your preferred editor
   nano terraform.tfvars
   # or
   vim terraform.tfvars
   # or
   code terraform.tfvars
   ```

3. Required values to update:
   - `vpc_id` - Your VPC ID
   - `subnet_ids` - Your private subnet IDs (at least 2)
   - `rds_security_group_id` - Your RDS security group ID
   - `container_image` - Your ECR image URI
   - `db_host` - Your RDS endpoint
   - `db_user` - Your database username
   - `db_password` - Your database password
   - `jwt_secret` - Your JWT secret
   - `alb_arn` - Your ALB ARN
   - `alb_listener_arn` - Your ALB listener ARN
   - `ecs_target_group_arn` - Your ECS target group ARN

## Step 3: Initialize Terraform

```bash
# Initialize Terraform (downloads providers and modules)
terraform init
```

Expected output:
```
Initializing the backend...
Initializing modules...
Initializing provider plugins...
Terraform has been successfully initialized!
```

## Step 4: Review the Plan

```bash
# Generate and review the execution plan
terraform plan
```

Review the output carefully. You should see:
- EKS cluster resources
- Node group resources
- Kubernetes resources
- ALB target group and listener rule

Estimated resources to create: ~30-40 resources

## Step 5: Apply the Configuration

```bash
# Apply the configuration (creates all resources)
terraform apply
```

When prompted, type `yes` to confirm.

**Estimated time**: 15-20 minutes
- EKS cluster creation: ~10 minutes
- Node group creation: ~5 minutes
- Kubernetes resources: ~2 minutes
- ALB integration: ~1 minute

## Step 6: Configure kubectl

After successful deployment, configure kubectl to access your cluster:

```bash
# Get the kubectl config command from Terraform output
terraform output kubectl_config_command

# Run the command (example)
aws eks update-kubeconfig --name backend-eks-exploration --region us-east-1
```

## Step 7: Verify Deployment

Run the verification commands:

```bash
# Check cluster nodes
kubectl get nodes

# Check pods
kubectl get pods -n backend

# Check services
kubectl get svc -n backend

# Check ingress
kubectl get ingress -n backend

# View pod logs
kubectl logs -n backend -l app=backend-api --tail=50

# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw eks_target_group_arn)
```

Expected results:
- 2 nodes in Ready state
- 2 pods in Running state
- 1 service (ClusterIP)
- 1 ingress with ALB address
- Healthy targets in target group

## Step 8: Test the Deployment

At this point, traffic is still going 100% to ECS (eks_weight = 0).

To test EKS without affecting production:

1. Get the ALB DNS name:
   ```bash
   aws elbv2 describe-load-balancers \
     --load-balancer-arns $(terraform output -raw alb_arn) \
     --query 'LoadBalancers[0].DNSName' \
     --output text
   ```

2. Test the health endpoint:
   ```bash
   curl http://<ALB-DNS-NAME>/health
   ```

## Step 9: Shift Traffic (Optional)

To gradually shift traffic from ECS to EKS:

1. Edit `terraform.tfvars`:
   ```hcl
   eks_weight = 10   # 10% to EKS
   ecs_weight = 90   # 90% to ECS
   ```

2. Apply the change:
   ```bash
   terraform apply
   ```

3. Monitor metrics in CloudWatch

4. Gradually increase eks_weight: 10 → 25 → 50 → 75 → 100

## Troubleshooting

### Pods not starting

```bash
# Describe pods to see events
kubectl describe pods -n backend

# Check pod logs
kubectl logs -n backend -l app=backend-api --tail=100
```

### Nodes not ready

```bash
# Check node status
kubectl describe nodes

# Check node group status
aws eks describe-nodegroup \
  --cluster-name backend-eks-exploration \
  --nodegroup-name backend-nodes
```

### Database connection issues

```bash
# Test database connectivity from pod
kubectl exec -n backend -it <pod-name> -- sh
# Inside pod:
nc -zv <db-host> 5432
```

### Target group unhealthy

```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw eks_target_group_arn)

# Check security groups
# Ensure ALB can reach pods on container port
```

## Rollback

To rollback and remove all EKS resources:

1. Shift traffic back to ECS:
   ```hcl
   eks_weight = 0
   ecs_weight = 100
   ```

2. Apply the change:
   ```bash
   terraform apply
   ```

3. Verify ECS is handling all traffic

4. Destroy EKS resources:
   ```bash
   terraform destroy
   ```

## Cost Monitoring

Set up billing alerts:

```bash
# Create a budget (example: $50/month)
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget file://budget.json \
  --notifications-with-subscribers file://notifications.json
```

## Next Steps

- [ ] Monitor CloudWatch metrics
- [ ] Set up CloudWatch alarms
- [ ] Configure CloudWatch Container Insights
- [ ] Set up log aggregation with Fluent Bit
- [ ] Test application functionality
- [ ] Perform load testing
- [ ] Document any issues or learnings

## Useful Commands

```bash
# View all Terraform outputs
terraform output

# View specific output
terraform output cluster_endpoint

# Refresh Terraform state
terraform refresh

# Show current state
terraform show

# List all resources
terraform state list

# Format Terraform files
terraform fmt -recursive

# Validate configuration
terraform validate
```

## Support

For issues or questions:
1. Check the main README.md
2. Review module-specific README files
3. Check AWS EKS documentation
4. Review Terraform Kubernetes provider docs
