# Troubleshooting Guide

## Overview

This guide provides solutions to common issues you may encounter during EKS deployment, operation, and rollback.

---

## Table of Contents

1. [Database Connectivity Issues](#database-connectivity-issues)
2. [ECR Image Pull Issues](#ecr-image-pull-issues)
3. [Pod Health Issues](#pod-health-issues)
4. [ALB Integration Issues](#alb-integration-issues)
5. [Terraform Issues](#terraform-issues)
6. [Cost Issues](#cost-issues)
7. [Verification Commands](#verification-commands)

---

## Database Connectivity Issues

### Issue: Pods Can't Connect to RDS

**Symptoms:**
- Pods show `CrashLoopBackOff`
- Logs show `ECONNREFUSED` or `timeout` errors
- Application can't query database

**Diagnosis:**
```bash
# Check pod logs
kubectl logs -n backend <pod-name>

# Test connectivity from pod
kubectl exec -it <pod-name> -n backend -- sh
nc -zv $DB_HOST 5432

# Check DNS resolution
nslookup $DB_HOST
```

**Common Causes & Solutions:**

**1. Security Group Not Configured**

```bash
# Check RDS security group
aws ec2 describe-security-groups --group-ids <rds-sg-id>

# Verify inbound rule exists for EKS node security group
# Should see: Type=PostgreSQL, Port=5432, Source=<eks-node-sg>

# Add rule if missing
aws ec2 authorize-security-group-ingress \
  --group-id <rds-sg-id> \
  --protocol tcp \
  --port 5432 \
  --source-group <eks-node-sg-id>
```

**2. Incorrect Database Credentials**

```bash
# Check secret values
kubectl get secret backend-secrets -n backend -o jsonpath='{.data.db_host}' | base64 --decode
kubectl get secret backend-secrets -n backend -o jsonpath='{.data.db_name}' | base64 --decode

# Update secret if incorrect
kubectl delete secret backend-secrets -n backend
kubectl create secret generic backend-secrets -n backend \
  --from-literal=db_host=correct-host \
  --from-literal=db_name=correct-name \
  --from-literal=db_user=correct-user \
  --from-literal=db_password=correct-password \
  --from-literal=jwt_secret=correct-secret

# Restart pods to pick up new secret
kubectl rollout restart deployment backend-api -n backend
```

**3. DNS Resolution Failure**

```bash
# Check CoreDNS is running
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check pod DNS configuration
kubectl exec -it <pod-name> -n backend -- cat /etc/resolv.conf

# Test DNS from pod
kubectl exec -it <pod-name> -n backend -- nslookup google.com

# If DNS fails, restart CoreDNS
kubectl rollout restart deployment coredns -n kube-system
```

**4. Network ACLs Blocking Traffic**

```bash
# Check subnet network ACLs
aws ec2 describe-network-acls \
  --filters "Name=association.subnet-id,Values=<subnet-id>"

# Verify rules allow:
# - Outbound: TCP 5432 to database subnets
# - Inbound: TCP 1024-65535 from database subnets (return traffic)
```

---

## ECR Image Pull Issues

### Issue: ImagePullBackOff Error

**Symptoms:**
- Pods stuck in `ImagePullBackOff` or `ErrImagePull`
- Events show "Failed to pull image"
- Pods never reach Running state

**Diagnosis:**
```bash
# Check pod events
kubectl describe pod <pod-name> -n backend

# Check image name
kubectl get deployment backend-api -n backend -o jsonpath='{.spec.template.spec.containers[0].image}'

# Check node IAM role
aws iam get-role --role-name eks-node-role
aws iam list-attached-role-policies --role-name eks-node-role
```

**Common Causes & Solutions:**

**1. Missing ECR Permissions**

```bash
# Verify node role has ECR policy
aws iam list-attached-role-policies --role-name eks-node-role | grep ContainerRegistry

# If missing, attach policy
aws iam attach-role-policy \
  --role-name eks-node-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

# Wait 1-2 minutes for IAM propagation, then delete pod to retry
kubectl delete pod <pod-name> -n backend
```

**2. Incorrect Image URI**

```bash
# Check image exists in ECR
aws ecr describe-images \
  --repository-name backend \
  --image-ids imageTag=latest

# Correct format:
# <account-id>.dkr.ecr.<region>.amazonaws.com/backend:latest

# Update deployment if incorrect
kubectl set image deployment/backend-api \
  backend=123456789012.dkr.ecr.us-east-1.amazonaws.com/backend:latest \
  -n backend
```

**3. ECR Repository in Different Region**

```bash
# Check repository region
aws ecr describe-repositories --repository-names backend

# If in different region, either:
# Option 1: Use correct region in image URI
# Option 2: Replicate image to cluster region
aws ecr put-image \
  --repository-name backend \
  --image-manifest "$(aws ecr batch-get-image --repository-name backend --image-ids imageTag=latest --query 'images[].imageManifest' --output text --region <source-region>)" \
  --image-tag latest \
  --region <cluster-region>
```

**4. Private ECR Requiring Authentication**

```bash
# For private ECR, create image pull secret
kubectl create secret docker-registry ecr-secret \
  --docker-server=<account-id>.dkr.ecr.<region>.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region <region>) \
  -n backend

# Update deployment to use secret
kubectl patch deployment backend-api -n backend -p '
{
  "spec": {
    "template": {
      "spec": {
        "imagePullSecrets": [{"name": "ecr-secret"}]
      }
    }
  }
}'
```

---

## Pod Health Issues

### Issue: Pods Failing Health Checks

**Symptoms:**
- Pods show `Running` but not `Ready`
- Frequent pod restarts
- Logs show health check failures

**Diagnosis:**
```bash
# Check pod status
kubectl get pods -n backend

# Check pod events
kubectl describe pod <pod-name> -n backend

# Check pod logs
kubectl logs <pod-name> -n backend --tail=100

# Check previous pod logs (if restarted)
kubectl logs <pod-name> -n backend --previous
```

**Common Causes & Solutions:**

**1. Application Not Starting**

```bash
# Check startup logs
kubectl logs <pod-name> -n backend --tail=200

# Common issues:
# - Missing environment variables
# - Database connection failure
# - Port already in use
# - Application crash

# Check environment variables
kubectl exec <pod-name> -n backend -- env | grep -E 'DB_|JWT_|PORT'

# Increase startup probe failure threshold if app is slow to start
kubectl patch deployment backend-api -n backend -p '
{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "backend",
          "startupProbe": {
            "failureThreshold": 60
          }
        }]
      }
    }
  }
}'
```

**2. Health Endpoint Not Responding**

```bash
# Test health endpoint from within pod
kubectl exec <pod-name> -n backend -- curl -I http://localhost:3000/health

# If 404, check if endpoint exists in application
# If timeout, check if application is listening on correct port

# Check application port
kubectl exec <pod-name> -n backend -- netstat -tlnp

# Update health check path if different
kubectl patch deployment backend-api -n backend -p '
{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "backend",
          "livenessProbe": {
            "httpGet": {
              "path": "/api/health"
            }
          }
        }]
      }
    }
  }
}'
```

**3. Resource Constraints**

```bash
# Check pod resource usage
kubectl top pod <pod-name> -n backend

# Check if pod is being OOMKilled
kubectl describe pod <pod-name> -n backend | grep -A 5 "Last State"

# If OOMKilled, increase memory limits
kubectl patch deployment backend-api -n backend -p '
{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "backend",
          "resources": {
            "limits": {
              "memory": "2Gi"
            }
          }
        }]
      }
    }
  }
}'
```

**4. Node Resource Exhaustion**

```bash
# Check node resources
kubectl top nodes

# Check pod scheduling
kubectl get pods -n backend -o wide

# If pods are Pending, check events
kubectl describe pod <pod-name> -n backend | grep -A 10 Events

# If "Insufficient cpu" or "Insufficient memory":
# Option 1: Scale down other workloads
# Option 2: Add more nodes
# Option 3: Reduce pod resource requests
```

---

## ALB Integration Issues

### Issue: ALB Not Routing to EKS

**Symptoms:**
- 503 errors when accessing application
- EKS target group shows no targets
- Traffic not reaching EKS pods

**Diagnosis:**
```bash
# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn <eks-tg-arn>

# Check ALB listener rules
aws elbv2 describe-rules \
  --listener-arn <listener-arn>

# Check ingress status
kubectl get ingress -n backend
kubectl describe ingress backend-api -n backend

# Check ALB controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

**Common Causes & Solutions:**

**1. ALB Controller Not Running**

```bash
# Check controller status
kubectl get deployment -n kube-system aws-load-balancer-controller

# If not found, install it
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=backend-eks-exploration \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=<role-arn>

# Check controller logs for errors
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=100
```

**2. Targets Not Registered**

```bash
# Check if ingress created target group
kubectl get ingress backend-api -n backend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Find target group in AWS Console with tag:
# kubernetes.io/ingress-name=backend-api

# Check security groups allow ALB → Pods
# ALB SG must allow outbound to node SG
# Node SG must allow inbound from ALB SG

# Verify pod IPs are registered
kubectl get pods -n backend -o wide
aws elbv2 describe-target-health --target-group-arn <tg-arn>
```

**3. Health Checks Failing**

```bash
# Check target health
aws elbv2 describe-target-health --target-group-arn <tg-arn>

# If unhealthy, check health check configuration
aws elbv2 describe-target-groups --target-group-arns <tg-arn>

# Test health endpoint from ALB's perspective
# (from a node in the same VPC)
curl -I http://<pod-ip>:3000/health

# Update health check if needed
aws elbv2 modify-target-group \
  --target-group-arn <tg-arn> \
  --health-check-path /health \
  --health-check-interval-seconds 15 \
  --health-check-timeout-seconds 5
```

**4. Weighted Routing Not Configured**

```bash
# Check listener rule
aws elbv2 describe-rules --listener-arn <listener-arn>

# Verify weighted routing includes EKS target group
# Should see both ECS and EKS target groups with weights

# Update if missing
aws elbv2 modify-listener \
  --listener-arn <listener-arn> \
  --default-actions Type=forward,ForwardConfig='{
    "TargetGroups":[
      {"TargetGroupArn":"<ecs-tg-arn>","Weight":100},
      {"TargetGroupArn":"<eks-tg-arn>","Weight":0}
    ]
  }'
```

---

## Terraform Issues

### Issue: Terraform Apply Fails

**Common Errors & Solutions:**

**1. "Error creating EKS Cluster: InvalidParameterException"**

```bash
# Check subnet IDs are valid
aws ec2 describe-subnets --subnet-ids <subnet-id>

# Verify subnets are in same VPC
# Verify subnets have available IPs
# Verify subnets are in different AZs

# Check IAM permissions
aws sts get-caller-identity
# Verify you have eks:CreateCluster permission
```

**2. "Error creating Node Group: InvalidParameterException"**

```bash
# Verify cluster exists and is ACTIVE
aws eks describe-cluster --name backend-eks-exploration

# Check node IAM role exists
aws iam get-role --role-name eks-node-role

# Verify instance type is available in region
aws ec2 describe-instance-type-offerings \
  --location-type availability-zone \
  --filters Name=instance-type,Values=t3.micro \
  --region us-east-1
```

**3. "Error: Kubernetes cluster unreachable"**

```bash
# Update kubeconfig
aws eks update-kubeconfig --name backend-eks-exploration --region us-east-1

# Test connection
kubectl get svc

# If still fails, check cluster endpoint access
aws eks describe-cluster --name backend-eks-exploration \
  --query 'cluster.resourcesVpcConfig.endpointPublicAccess'

# Should be true for kubectl access
```

**4. "Error: timeout while waiting for state to become 'ACTIVE'"**

```bash
# Check cluster status
aws eks describe-cluster --name backend-eks-exploration \
  --query 'cluster.status'

# If CREATING for > 15 minutes, check CloudTrail for errors
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=backend-eks-exploration \
  --max-results 10

# May need to destroy and recreate
terraform destroy -target=module.eks_cluster
terraform apply -target=module.eks_cluster
```

---

## Cost Issues

### Issue: Unexpected High Costs

**Diagnosis:**
```bash
# Check current month costs
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '1 day ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=SERVICE

# Check for running resources
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running"
aws eks list-clusters
aws elbv2 describe-load-balancers
aws ec2 describe-nat-gateways --filter "Name=state,Values=available"
```

**Common Causes & Solutions:**

**1. EKS Cluster Still Running**

```bash
# Verify cluster is deleted
aws eks list-clusters

# If still exists, destroy it
cd infrastructure/terraform/eks-migration/environments/exploration
terraform destroy
```

**2. Orphaned EC2 Instances**

```bash
# Find EKS-related instances
aws ec2 describe-instances \
  --filters "Name=tag:kubernetes.io/cluster/backend-eks-exploration,Values=owned" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name]'

# Terminate if any found
aws ec2 terminate-instances --instance-ids <instance-id>
```

**3. Orphaned EBS Volumes**

```bash
# Find available volumes
aws ec2 describe-volumes \
  --filters "Name=status,Values=available" \
  --query 'Volumes[].[VolumeId,Size,CreateTime]'

# Delete if not needed
aws ec2 delete-volume --volume-id <volume-id>
```

**4. Data Transfer Costs**

```bash
# Check data transfer
# Usually from:
# - NAT Gateway usage
# - Inter-AZ traffic
# - Internet egress

# Minimize by:
# - Keeping workloads in same AZ when possible
# - Using VPC endpoints for AWS services
# - Reducing log verbosity
```

---

## Verification Commands

### Cluster Health

```bash
# Cluster status
aws eks describe-cluster --name backend-eks-exploration --query 'cluster.status'

# Node status
kubectl get nodes

# System pods
kubectl get pods -n kube-system

# CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

### Application Health

```bash
# Pods
kubectl get pods -n backend

# Deployment
kubectl get deployment -n backend

# Service
kubectl get svc -n backend

# Ingress
kubectl get ingress -n backend

# Logs
kubectl logs -n backend -l app=backend-api --tail=50
```

### Network Connectivity

```bash
# Pod to pod
kubectl exec -it <pod1> -n backend -- curl http://<pod2-ip>:3000/health

# Pod to service
kubectl exec -it <pod> -n backend -- curl http://backend-api.backend.svc.cluster.local/health

# Pod to RDS
kubectl exec -it <pod> -n backend -- nc -zv $DB_HOST 5432

# Pod to internet
kubectl exec -it <pod> -n backend -- curl -I https://google.com
```

### ALB and Target Groups

```bash
# Target health
aws elbv2 describe-target-health --target-group-arn <tg-arn>

# Listener rules
aws elbv2 describe-rules --listener-arn <listener-arn>

# ALB access logs (if enabled)
aws s3 ls s3://<alb-logs-bucket>/AWSLogs/<account-id>/elasticloadbalancing/
```

### Resource Usage

```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl top pods -n backend

# Cluster capacity
kubectl describe nodes | grep -A 5 "Allocated resources"
```

### Security

```bash
# Security groups
aws ec2 describe-security-groups --group-ids <sg-id>

# IAM roles
aws iam get-role --role-name eks-cluster-role
aws iam get-role --role-name eks-node-role

# Secrets
kubectl get secrets -n backend
kubectl describe secret backend-secrets -n backend
```

---

## Quick Fixes

### Restart Everything

```bash
# Restart pods
kubectl rollout restart deployment backend-api -n backend

# Restart CoreDNS
kubectl rollout restart deployment coredns -n kube-system

# Restart ALB controller
kubectl rollout restart deployment aws-load-balancer-controller -n kube-system
```

### Force Pod Deletion

```bash
# If pod stuck in Terminating
kubectl delete pod <pod-name> -n backend --force --grace-period=0
```

### Reset Deployment

```bash
# Scale to 0 and back
kubectl scale deployment backend-api -n backend --replicas=0
kubectl scale deployment backend-api -n backend --replicas=2
```

### Clear Failed Pods

```bash
# Delete all failed pods
kubectl delete pods -n backend --field-selector status.phase=Failed
```

---

## Getting Help

If issues persist:

1. **Check AWS Service Health**: https://status.aws.amazon.com/
2. **Review CloudWatch Logs**: Check for error patterns
3. **Check CloudTrail**: Look for API errors
4. **AWS Support**: Contact AWS Support if infrastructure issues
5. **Kubernetes Community**: https://kubernetes.io/community/

---

**Remember:** When in doubt, you can always rollback to ECS safely!
