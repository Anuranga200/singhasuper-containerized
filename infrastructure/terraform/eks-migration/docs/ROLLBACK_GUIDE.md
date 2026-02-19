# Rollback Guide: Return to ECS

## Overview

This guide provides step-by-step instructions for safely rolling back from EKS to ECS after your exploration is complete.

**Estimated Time:** 40-50 minutes  
**Risk Level:** Low (ECS remains unchanged throughout)  
**Rollback Success Rate:** 100% (if steps followed correctly)

---

## Table of Contents

1. [Pre-Rollback Checklist](#pre-rollback-checklist)
2. [Traffic Rollback Procedure](#traffic-rollback-procedure)
3. [Terraform Destroy Procedure](#terraform-destroy-procedure)
4. [Manual Resource Cleanup](#manual-resource-cleanup)
5. [kubectl Cleanup](#kubectl-cleanup)
6. [Rollback Verification](#rollback-verification)
7. [Troubleshooting](#troubleshooting)

---

## Pre-Rollback Checklist

Before starting rollback, verify:

- [ ] ECS target group is healthy
- [ ] ECS tasks are running normally
- [ ] You have documented any learnings/observations
- [ ] You have exported any logs or metrics you want to keep
- [ ] You have noted final AWS costs
- [ ] You have admin access to AWS Console and CLI
- [ ] You have backed up any custom configurations

**Time to complete checklist:** 10 minutes

---

## Traffic Rollback Procedure

**Time:** 5-10 minutes  
**Risk:** Low (instant rollback if issues)

### Step 1: Shift 100% Traffic to ECS

#### Method 1: Terraform (Recommended)

```bash
cd infrastructure/terraform/eks-migration/environments/exploration

# Edit terraform.tfvars
# Change:
eks_weight = 0
ecs_weight = 100

# Apply changes
terraform apply -target=module.alb_integration

# Confirm when prompted
```

#### Method 2: AWS CLI

```bash
# Get ARNs
ECS_TG_ARN=$(terraform output -raw ecs_target_group_arn)
EKS_TG_ARN=$(terraform output -raw eks_target_group_arn)
LISTENER_ARN=$(terraform output -raw alb_listener_arn)

# Shift all traffic to ECS
aws elbv2 modify-listener \
  --listener-arn $LISTENER_ARN \
  --default-actions Type=forward,ForwardConfig='{
    "TargetGroups":[
      {"TargetGroupArn":"'$ECS_TG_ARN'","Weight":100},
      {"TargetGroupArn":"'$EKS_TG_ARN'","Weight":0}
    ]
  }'
```

#### Method 3: AWS Console

1. Navigate to **EC2** → **Load Balancers**
2. Select your ALB
3. Go to **Listeners** tab
4. Click on listener → **View/edit rules**
5. Find your weighted routing rule
6. Edit the rule:
   - ECS target group: Weight `100`
   - EKS target group: Weight `0`
7. Save changes

### Step 2: Verify ECS Traffic

```bash
# Check ECS target health
aws elbv2 describe-target-health \
  --target-group-arn $ECS_TG_ARN

# Expected: All targets healthy

# Monitor ECS metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=backend-service \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### Step 3: Test Application

```bash
# Test health endpoint
curl -I http://your-alb-dns-name/health

# Expected: HTTP/1.1 200 OK

# Test a few API endpoints
curl http://your-alb-dns-name/api/customers

# Verify responses are correct
```

### Step 4: Monitor for 15-30 Minutes

**Watch for:**
- ✅ ECS target health remains healthy
- ✅ No increase in error rates
- ✅ Response times are normal
- ✅ No application errors in logs

```bash
# Watch ECS logs
aws logs tail /ecs/backend-service --follow

# Check for errors
aws logs filter-log-events \
  --log-group-name /ecs/backend-service \
  --filter-pattern "ERROR" \
  --start-time $(date -u -d '30 minutes ago' +%s)000
```

**If any issues detected:** ECS should handle traffic normally. If not, investigate ECS configuration (not related to EKS rollback).

---

## Terraform Destroy Procedure

**Time:** 25-30 minutes  
**Risk:** Low (only destroys EKS resources)

### Step 1: Prepare for Destroy

```bash
cd infrastructure/terraform/eks-migration/environments/exploration

# Review what will be destroyed
terraform plan -destroy

# Verify only EKS resources are listed:
# - EKS cluster
# - EKS node group
# - EKS target group
# - IAM roles for EKS
# - Security groups for EKS
# - Kubernetes resources
```

**IMPORTANT:** Verify that ECS resources are NOT in the destroy list!

### Step 2: Destroy Kubernetes Resources First

```bash
# This prevents issues with ALB controller trying to clean up
terraform destroy -target=module.kubernetes_resources

# Confirm when prompted
```

**Wait:** 2-3 minutes

### Step 3: Destroy ALB Integration

```bash
terraform destroy -target=module.alb_integration

# This removes:
# - EKS target group
# - Weighted listener rule
```

**Wait:** 1-2 minutes

### Step 4: Destroy Node Group

```bash
terraform destroy -target=module.eks_node_group

# This removes:
# - Node group
# - Node IAM role
# - Node security group
```

**Wait:** 5-7 minutes

### Step 5: Destroy EKS Cluster

```bash
terraform destroy -target=module.eks_cluster

# This removes:
# - EKS cluster
# - Cluster IAM role
# - Cluster security group
# - OIDC provider
```

**Wait:** 10-12 minutes

### Step 6: Destroy Remaining Resources

```bash
# Destroy any remaining resources
terraform destroy

# Confirm when prompted
```

**Wait:** 2-3 minutes

### Alternative: Destroy Everything at Once

```bash
# If you're confident, destroy all at once
terraform destroy

# Confirm when prompted
```

**Wait:** 15-20 minutes

**Note:** This may fail if resources have dependencies. If it fails, use the step-by-step approach above.

---

## Manual Resource Cleanup

**Time:** 10-15 minutes  
**Risk:** Low

Some resources may not be managed by Terraform and need manual cleanup.

### Step 1: CloudWatch Log Groups

```bash
# List EKS-related log groups
aws logs describe-log-groups \
  --log-group-name-prefix /aws/eks/backend-eks-exploration

# Delete log groups
aws logs delete-log-group \
  --log-group-name /aws/eks/backend-eks-exploration/cluster

aws logs delete-log-group \
  --log-group-name /aws/containerinsights/backend-eks-exploration/performance

aws logs delete-log-group \
  --log-group-name /aws/eks/backend-eks-exploration/application
```

### Step 2: CloudWatch Alarms

```bash
# List EKS-related alarms
aws cloudwatch describe-alarms \
  --alarm-name-prefix backend-eks-exploration

# Delete alarms
aws cloudwatch delete-alarms \
  --alarm-names \
    backend-eks-exploration-low-node-count \
    backend-eks-exploration-high-cpu-utilization \
    backend-eks-exploration-high-memory-utilization \
    backend-eks-exploration-unhealthy-targets \
    backend-eks-exploration-high-5xx-errors
```

### Step 3: SNS Topics

```bash
# List EKS-related SNS topics
aws sns list-topics \
  --query 'Topics[?contains(TopicArn, `eks-alarms`)].TopicArn'

# Delete SNS topic
aws sns delete-topic \
  --topic-arn arn:aws:sns:us-east-1:ACCOUNT_ID:backend-eks-exploration-eks-alarms
```

### Step 4: IAM Roles (if not destroyed by Terraform)

```bash
# List EKS-related IAM roles
aws iam list-roles \
  --query 'Roles[?contains(RoleName, `eks`)].RoleName'

# If any remain, delete them:
# 1. Detach policies
aws iam list-attached-role-policies --role-name ROLE_NAME
aws iam detach-role-policy --role-name ROLE_NAME --policy-arn POLICY_ARN

# 2. Delete role
aws iam delete-role --role-name ROLE_NAME
```

### Step 5: Security Groups (if not destroyed by Terraform)

```bash
# List EKS-related security groups
aws ec2 describe-security-groups \
  --filters "Name=tag:kubernetes.io/cluster/backend-eks-exploration,Values=owned" \
  --query 'SecurityGroups[].GroupId'

# Delete security groups (if any remain)
aws ec2 delete-security-group --group-id sg-xxxxx
```

### Step 6: Network Interfaces

```bash
# List orphaned network interfaces
aws ec2 describe-network-interfaces \
  --filters "Name=description,Values=*eks*" \
  --query 'NetworkInterfaces[?Status==`available`].NetworkInterfaceId'

# Delete if any found
aws ec2 delete-network-interface --network-interface-id eni-xxxxx
```

---

## kubectl Cleanup

**Time:** 2-3 minutes  
**Risk:** None

### Step 1: Remove kubeconfig Context

```bash
# List contexts
kubectl config get-contexts

# Delete EKS context
kubectl config delete-context arn:aws:eks:us-east-1:ACCOUNT_ID:cluster/backend-eks-exploration

# Delete cluster entry
kubectl config delete-cluster arn:aws:eks:us-east-1:ACCOUNT_ID:cluster/backend-eks-exploration

# Delete user entry
kubectl config delete-user arn:aws:eks:us-east-1:ACCOUNT_ID:cluster/backend-eks-exploration
```

### Step 2: Clean Up Local Files

```bash
# Remove Terraform state (if using local backend)
cd infrastructure/terraform/eks-migration/environments/exploration
rm -rf .terraform terraform.tfstate* .terraform.lock.hcl

# Remove any downloaded files
rm -f iam-policy.json kubeconfig-*.yaml
```

---

## Rollback Verification

**Time:** 5-10 minutes

### Verification Checklist

Run these commands to verify complete cleanup:

```bash
# 1. EKS cluster deleted
aws eks list-clusters
# Expected: backend-eks-exploration NOT in list

# 2. No EKS nodes running
aws ec2 describe-instances \
  --filters "Name=tag:kubernetes.io/cluster/backend-eks-exploration,Values=owned" \
  --query 'Reservations[].Instances[?State.Name==`running`].InstanceId'
# Expected: Empty list

# 3. No EKS security groups
aws ec2 describe-security-groups \
  --filters "Name=tag:kubernetes.io/cluster/backend-eks-exploration,Values=owned" \
  --query 'SecurityGroups[].GroupId'
# Expected: Empty list

# 4. No EKS target groups
aws elbv2 describe-target-groups \
  --query 'TargetGroups[?contains(TargetGroupName, `eks`)].TargetGroupName'
# Expected: Empty list or no eks-backend-tg

# 5. ECS is healthy
aws elbv2 describe-target-health \
  --target-group-arn $ECS_TG_ARN
# Expected: All targets healthy

# 6. ECS tasks running
aws ecs list-tasks --cluster backend-cluster --service-name backend-service
# Expected: 2 tasks running

# 7. Application responding
curl -I http://your-alb-dns-name/health
# Expected: HTTP/1.1 200 OK

# 8. No kubectl context
kubectl config get-contexts | grep eks
# Expected: No output
```

### ECS Health Check

```bash
# Check ECS service
aws ecs describe-services \
  --cluster backend-cluster \
  --services backend-service \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}'

# Expected:
# {
#   "Status": "ACTIVE",
#   "Running": 2,
#   "Desired": 2
# }

# Check ECS task health
aws ecs describe-tasks \
  --cluster backend-cluster \
  --tasks $(aws ecs list-tasks --cluster backend-cluster --service-name backend-service --query 'taskArns[0]' --output text) \
  --query 'tasks[0].{Status:lastStatus,Health:healthStatus}'

# Expected:
# {
#   "Status": "RUNNING",
#   "Health": "HEALTHY"
# }
```

### Cost Verification

```bash
# Check current month costs
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '1 day ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=SERVICE \
  --filter file://filter.json

# filter.json:
# {
#   "Tags": {
#     "Key": "kubernetes.io/cluster/backend-eks-exploration",
#     "Values": ["owned"]
#   }
# }

# Expected: No EKS costs after 24 hours
```

---

## Troubleshooting

### Issue: Terraform Destroy Fails

**Error:** "Error deleting EKS Cluster: ResourceInUseException"

**Solution:**
```bash
# 1. Check for remaining node groups
aws eks list-nodegroups --cluster-name backend-eks-exploration

# 2. Delete node groups manually
aws eks delete-nodegroup \
  --cluster-name backend-eks-exploration \
  --nodegroup-name backend-nodes

# 3. Wait for deletion
aws eks describe-nodegroup \
  --cluster-name backend-eks-exploration \
  --nodegroup-name backend-nodes \
  --query 'nodegroup.status'

# 4. Retry terraform destroy
terraform destroy -target=module.eks_cluster
```

### Issue: Security Group Can't Be Deleted

**Error:** "DependencyViolation: resource has a dependent object"

**Solution:**
```bash
# 1. Find network interfaces using the security group
aws ec2 describe-network-interfaces \
  --filters "Name=group-id,Values=sg-xxxxx" \
  --query 'NetworkInterfaces[].NetworkInterfaceId'

# 2. Delete network interfaces
aws ec2 delete-network-interface --network-interface-id eni-xxxxx

# 3. Wait 2-3 minutes

# 4. Retry security group deletion
aws ec2 delete-security-group --group-id sg-xxxxx
```

### Issue: ECS Not Receiving Traffic

**Error:** 503 errors or no response

**Solution:**
```bash
# 1. Check ECS target health
aws elbv2 describe-target-health --target-group-arn $ECS_TG_ARN

# 2. Check ALB listener rules
aws elbv2 describe-rules --listener-arn $LISTENER_ARN

# 3. Verify ECS service is running
aws ecs describe-services \
  --cluster backend-cluster \
  --services backend-service

# 4. Check ECS task logs
aws logs tail /ecs/backend-service --follow

# 5. If needed, restart ECS service
aws ecs update-service \
  --cluster backend-cluster \
  --service backend-service \
  --force-new-deployment
```

### Issue: High AWS Costs After Rollback

**Error:** Unexpected charges continue

**Solution:**
```bash
# 1. Check for running EC2 instances
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0]]'

# 2. Check for EBS volumes
aws ec2 describe-volumes \
  --filters "Name=status,Values=available" \
  --query 'Volumes[].[VolumeId,Size,CreateTime]'

# 3. Check for load balancers
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[].[LoadBalancerName,State.Code]'

# 4. Check for NAT gateways
aws ec2 describe-nat-gateways \
  --filter "Name=state,Values=available" \
  --query 'NatGateways[].[NatGatewayId,VpcId]'

# 5. Use Cost Explorer to identify charges
# Navigate to AWS Console → Cost Explorer → Cost and Usage Reports
```

---

## Rollback Verification Checklist

After completing all steps, verify:

- [ ] EKS cluster is deleted
- [ ] No EKS nodes are running
- [ ] No EKS security groups remain
- [ ] No EKS target groups remain
- [ ] ECS target group is healthy (all targets healthy)
- [ ] ECS tasks are running (2/2)
- [ ] Application responds correctly (200 OK)
- [ ] No kubectl context for EKS
- [ ] CloudWatch log groups deleted
- [ ] CloudWatch alarms deleted
- [ ] SNS topics deleted
- [ ] No unexpected AWS costs
- [ ] Terraform state is clean
- [ ] Local files cleaned up

**All items checked?** ✅ Rollback complete!

---

## Post-Rollback Actions

### 1. Document Learnings

Create a summary of your EKS exploration:
- What worked well?
- What challenges did you face?
- How does EKS compare to ECS for your use case?
- Would you consider EKS for production?
- What was the actual cost?

### 2. Review Final Costs

```bash
# Get final cost report
aws ce get-cost-and-usage \
  --time-period Start=2026-02-01,End=2026-02-28 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

### 3. Update Documentation

If you made any customizations or discovered useful patterns, document them for future reference.

### 4. Backup Configurations

Save any custom configurations or scripts you created:
```bash
# Backup terraform.tfvars
cp terraform.tfvars terraform.tfvars.backup

# Backup any custom scripts
tar -czf eks-exploration-backup.tar.gz \
  terraform.tfvars \
  custom-scripts/ \
  notes.md
```

---

## Estimated Time Summary

| Phase | Time |
|-------|------|
| Pre-Rollback Checklist | 10 min |
| Traffic Rollback | 5-10 min |
| Terraform Destroy | 25-30 min |
| Manual Cleanup | 10-15 min |
| kubectl Cleanup | 2-3 min |
| Verification | 5-10 min |
| **Total** | **40-50 min** |

---

## Success Criteria

Rollback is successful when:

✅ ECS is handling 100% of traffic  
✅ All EKS resources are deleted  
✅ No unexpected AWS costs  
✅ Application is functioning normally  
✅ All verification checks pass  

---

**Rollback Complete!** 🎉

You've successfully returned to ECS. Your application is running on the original infrastructure with no impact from the EKS exploration.

**Next Steps:**
- Review your learnings
- Check final AWS bill
- Consider whether EKS makes sense for future projects
- Keep this guide for future reference

---

**Need Help?** Review the troubleshooting section or check AWS Support.
