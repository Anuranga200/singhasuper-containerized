# Manual Console Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying EKS using the AWS Console. This approach is ideal for learning and understanding each component.

**Estimated Time:** 2.5-3 hours  
**Difficulty:** Intermediate  
**Prerequisites:** AWS account with appropriate permissions

---

## Table of Contents

1. [EKS Cluster Creation](#1-eks-cluster-creation)
2. [Node Group Creation](#2-node-group-creation)
3. [kubectl and AWS CLI Setup](#3-kubectl-and-aws-cli-setup)
4. [Kubernetes Deployment](#4-kubernetes-deployment)
5. [ALB Configuration](#5-alb-configuration)
6. [AWS Load Balancer Controller Installation](#6-aws-load-balancer-controller-installation)

---

## 1. EKS Cluster Creation

**Time:** 30-40 minutes

### Step 1.1: Create Cluster IAM Role

1. Navigate to **IAM Console** → **Roles** → **Create role**
2. Select **AWS service** → **EKS** → **EKS - Cluster**
3. Click **Next**
4. Policies are automatically attached:
   - `AmazonEKSClusterPolicy`
   - `AmazonEKSVPCResourceController`
5. Click **Next**
6. Role name: `eks-cluster-role`
7. Click **Create role**

**Why:** EKS needs permissions to manage AWS resources on your behalf.

### Step 1.2: Create EKS Cluster

1. Navigate to **EKS Console** → **Clusters** → **Create cluster**

2. **Configure cluster:**
   - Name: `backend-eks-exploration`
   - Kubernetes version: `1.28`
   - Cluster service role: Select `eks-cluster-role`

3. **Networking:**
   - VPC: Select your existing VPC
   - Subnets: Select private subnets in 2+ AZs
   - Security groups: Leave default (EKS creates one)
   - Cluster endpoint access:
     - ✅ Public
     - ✅ Private

4. **Observability:**
   - Control plane logging: Enable all log types
     - ✅ API server
     - ✅ Audit
     - ✅ Authenticator
     - ✅ Controller manager
     - ✅ Scheduler

5. **Add-ons:**
   - Keep defaults (CoreDNS, kube-proxy, VPC CNI)

6. **Review and create**

7. Wait 10-12 minutes for cluster creation

**Verification:**
```bash
aws eks describe-cluster --name backend-eks-exploration --query cluster.status
# Expected: "ACTIVE"
```

---

## 2. Node Group Creation

**Time:** 20-30 minutes

### Step 2.1: Create Node IAM Role

1. Navigate to **IAM Console** → **Roles** → **Create role**
2. Select **AWS service** → **EC2**
3. Click **Next**
4. Attach policies:
   - `AmazonEKSWorkerNodePolicy`
   - `AmazonEKS_CNI_Policy`
   - `AmazonEC2ContainerRegistryReadOnly`
   - `CloudWatchAgentServerPolicy`
5. Click **Next**
6. Role name: `eks-node-role`
7. Click **Create role**

**Why:** Nodes need permissions to join cluster, pull images, and send logs.

### Step 2.2: Create Node Group

1. Navigate to **EKS Console** → **Clusters** → `backend-eks-exploration`
2. Go to **Compute** tab → **Add node group**

3. **Configure node group:**
   - Name: `backend-nodes`
   - Node IAM role: Select `eks-node-role`

4. **Set compute and scaling configuration:**
   - AMI type: `Amazon Linux 2 (AL2_x86_64)`
   - Capacity type: `On-Demand`
   - Instance types: `t3.micro` (for free tier)
   - Disk size: `20 GB`
   
5. **Node group scaling configuration:**
   - Desired size: `2`
   - Minimum size: `2`
   - Maximum size: `3`

6. **Node group network configuration:**
   - Subnets: Select same private subnets as cluster
   - Configure remote access: No (not needed)

7. **Review and create**

8. Wait 5-7 minutes for nodes to be ready

**Verification:**
```bash
kubectl get nodes
# Expected: 2 nodes in Ready status
```

### Step 2.3: Configure RDS Security Group

1. Navigate to **EC2 Console** → **Security Groups**
2. Find your RDS security group
3. Click **Edit inbound rules** → **Add rule**
4. Configure:
   - Type: `PostgreSQL`
   - Port: `5432`
   - Source: Select node security group (starts with `eks-cluster-sg-`)
5. Click **Save rules**

**Why:** Allows EKS pods to connect to RDS database.

---

## 3. kubectl and AWS CLI Setup

**Time:** 10 minutes

### Step 3.1: Install kubectl

**Windows:**
```powershell
curl -LO "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"
# Move to PATH location
```

**macOS:**
```bash
brew install kubectl
```

**Linux:**
```bash
curl -LO "https://dl.k8s.io/release/v1.28.0/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

### Step 3.2: Install AWS CLI

**Windows:**
Download and run: https://awscli.amazonaws.com/AWSCLIV2.msi

**macOS:**
```bash
brew install awscli
```

**Linux:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### Step 3.3: Configure AWS Credentials

```bash
aws configure
# Enter:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (e.g., us-east-1)
# - Default output format (json)
```

### Step 3.4: Generate kubeconfig

```bash
aws eks update-kubeconfig --region us-east-1 --name backend-eks-exploration
```

**Verification:**
```bash
kubectl get svc
# Expected: kubernetes service listed
```

---

## 4. Kubernetes Deployment

**Time:** 30-40 minutes

### Step 4.1: Create Namespace

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: backend
  labels:
    name: backend
    environment: exploration
EOF
```

**Verification:**
```bash
kubectl get namespace backend
```

### Step 4.2: Create Secrets

**IMPORTANT:** Replace placeholder values with actual credentials!

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: backend-secrets
  namespace: backend
type: Opaque
stringData:
  db_host: "your-rds-endpoint.region.rds.amazonaws.com"
  db_name: "backend_production"
  db_user: "backend_user"
  db_password: "YOUR_ACTUAL_PASSWORD"
  jwt_secret: "YOUR_ACTUAL_JWT_SECRET"
EOF
```

**Verification:**
```bash
kubectl get secret backend-secrets -n backend
```

### Step 4.3: Deploy Application

**IMPORTANT:** Replace `<AWS_ACCOUNT_ID>` and `<AWS_REGION>` with your values!

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-api
  namespace: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend-api
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: backend-api
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - backend-api
              topologyKey: kubernetes.io/hostname
      containers:
      - name: backend
        image: <AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com/backend:latest
        ports:
        - containerPort: 3000
          name: http
        env:
        - name: NODE_ENV
          value: "production"
        - name: PORT
          value: "3000"
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: backend-secrets
              key: db_host
        - name: DB_PORT
          value: "5432"
        - name: DB_NAME
          valueFrom:
            secretKeyRef:
              name: backend-secrets
              key: db_name
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: backend-secrets
              key: db_user
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: backend-secrets
              key: db_password
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: backend-secrets
              key: jwt_secret
        resources:
          requests:
            cpu: "250m"
            memory: "512Mi"
          limits:
            cpu: "500m"
            memory: "1Gi"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
        startupProbe:
          httpGet:
            path: /health
            port: 3000
          failureThreshold: 30
          periodSeconds: 5
EOF
```

**Verification:**
```bash
kubectl get pods -n backend
# Wait for both pods to show Running status

kubectl logs -n backend -l app=backend-api --tail=50
# Check for any errors
```

### Step 4.4: Create Service

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: backend-api
  namespace: backend
spec:
  type: ClusterIP
  selector:
    app: backend-api
  ports:
  - port: 80
    targetPort: 3000
    protocol: TCP
    name: http
EOF
```

**Verification:**
```bash
kubectl get svc -n backend
```

### Step 4.5: Test Database Connectivity

```bash
# Get pod name
POD_NAME=$(kubectl get pods -n backend -l app=backend-api -o jsonpath='{.items[0].metadata.name}')

# Test database connection
kubectl exec -it $POD_NAME -n backend -- sh -c "nc -zv \$DB_HOST 5432"
# Expected: Connection successful
```

---

## 5. ALB Configuration

**Time:** 20-30 minutes

### Step 5.1: Create Target Group

1. Navigate to **EC2 Console** → **Target Groups** → **Create target group**

2. **Basic configuration:**
   - Target type: `IP addresses`
   - Target group name: `eks-backend-tg`
   - Protocol: `HTTP`
   - Port: `80`
   - VPC: Select your VPC

3. **Health checks:**
   - Health check protocol: `HTTP`
   - Health check path: `/health`
   - Advanced settings:
     - Healthy threshold: `2`
     - Unhealthy threshold: `2`
     - Timeout: `5 seconds`
     - Interval: `15 seconds`
     - Success codes: `200`

4. Click **Next**

5. **Register targets:** Skip (ALB controller will register pods automatically)

6. Click **Create target group**

**Note the Target Group ARN** - you'll need it later.

### Step 5.2: Configure ALB Listener Rule

1. Navigate to **EC2 Console** → **Load Balancers**
2. Select your existing ALB
3. Go to **Listeners** tab
4. Select your listener (usually port 80 or 443)
5. Click **View/edit rules**

6. **Add new rule:**
   - Click **Insert Rule** (at top)
   - Priority: `100` (higher than default)
   
7. **Add condition:**
   - Type: `Path`
   - Value: `/*` (all paths)

8. **Add action:**
   - Type: `Forward to target groups`
   - Target groups:
     - Add your ECS target group: Weight `100`
     - Add your EKS target group: Weight `0`
   - Group-level stickiness: `Off`

9. Click **Save**

**Why:** This creates weighted routing. Start with 0% to EKS for safety.

### Step 5.3: Verify Target Group

```bash
# Get target group ARN
TG_ARN="arn:aws:elasticloadbalancing:region:account:targetgroup/eks-backend-tg/xxxxx"

# Check target health (should be empty initially)
aws elbv2 describe-target-health --target-group-arn $TG_ARN
```

---

## 6. AWS Load Balancer Controller Installation

**Time:** 15-20 minutes

### Step 6.1: Install Helm

**Windows:**
```powershell
choco install kubernetes-helm
```

**macOS:**
```bash
brew install helm
```

**Linux:**
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Step 6.2: Create IAM Policy for ALB Controller

1. Download IAM policy:
```bash
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.0/docs/install/iam_policy.json
```

2. Create policy:
```bash
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam-policy.json
```

**Note the Policy ARN** - you'll need it next.

### Step 6.3: Create IAM Role for Service Account (IRSA)

1. Get OIDC provider URL:
```bash
aws eks describe-cluster --name backend-eks-exploration \
  --query "cluster.identity.oidc.issuer" --output text
# Example output: https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE
```

2. Create OIDC provider (if not exists):
```bash
eksctl utils associate-iam-oidc-provider \
  --region us-east-1 \
  --cluster backend-eks-exploration \
  --approve
```

3. Create IAM role:
```bash
eksctl create iamserviceaccount \
  --cluster=backend-eks-exploration \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --approve
```

### Step 6.4: Install ALB Controller via Helm

```bash
# Add Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=backend-eks-exploration \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

**Verification:**
```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
# Expected: 2/2 ready

kubectl logs -n kube-system deployment/aws-load-balancer-controller
# Check for any errors
```

### Step 6.5: Create Ingress

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backend-api
  namespace: backend
  annotations:
    alb.ingress.kubernetes.io/scheme: internal
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: "15"
    alb.ingress.kubernetes.io/target-group-attributes: deregistration_delay.timeout_seconds=30
spec:
  ingressClassName: alb
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: backend-api
            port:
              number: 80
EOF
```

**Verification:**
```bash
kubectl get ingress -n backend
# Wait for ADDRESS to be populated (2-3 minutes)

kubectl describe ingress backend-api -n backend
# Check events for target group creation
```

### Step 6.6: Link Ingress Target Group to ALB

1. Get the target group created by ingress:
```bash
kubectl get ingress backend-api -n backend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

2. Find the target group in AWS Console:
   - Navigate to **EC2** → **Target Groups**
   - Look for target group with tag `kubernetes.io/ingress-name=backend-api`
   - Note the ARN

3. Update ALB listener rule:
   - Go back to your ALB listener rules
   - Edit the rule you created earlier
   - Replace the EKS target group with the one created by ingress
   - Keep weight at `0` initially

---

## Verification Checklist

After completing all steps, verify:

```bash
# 1. Cluster is active
aws eks describe-cluster --name backend-eks-exploration --query cluster.status

# 2. Nodes are ready
kubectl get nodes

# 3. Pods are running
kubectl get pods -n backend

# 4. Service exists
kubectl get svc -n backend

# 5. Ingress is configured
kubectl get ingress -n backend

# 6. Target group has healthy targets
aws elbv2 describe-target-health --target-group-arn <YOUR_TG_ARN>

# 7. ALB controller is running
kubectl get deployment -n kube-system aws-load-balancer-controller
```

**All checks should pass!** ✅

---

## Next Steps

1. **Monitor for 1-2 hours** with 0% traffic to EKS
2. **Begin traffic shifting** (see main README)
3. **Compare metrics** in CloudWatch
4. **When done, follow rollback guide**

---

## Troubleshooting

### Pods not starting

**Check pod events:**
```bash
kubectl describe pod <pod-name> -n backend
```

**Common issues:**
- ImagePullBackOff: Check ECR permissions
- CrashLoopBackOff: Check application logs
- Pending: Check node resources

### Database connection fails

**Test from pod:**
```bash
kubectl exec -it <pod-name> -n backend -- sh
nc -zv $DB_HOST 5432
```

**Check:**
- RDS security group allows node security group
- DNS resolution works
- Credentials are correct

### ALB controller not working

**Check controller logs:**
```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

**Common issues:**
- IAM permissions missing
- IRSA not configured correctly
- Ingress annotations incorrect

---

## Estimated Time Summary

| Phase | Time |
|-------|------|
| EKS Cluster Creation | 30-40 min |
| Node Group Creation | 20-30 min |
| kubectl Setup | 10 min |
| Kubernetes Deployment | 30-40 min |
| ALB Configuration | 20-30 min |
| ALB Controller Installation | 15-20 min |
| **Total** | **2.5-3 hours** |

---

## Cost Reminder

This deployment will cost approximately **$18-25/week**. Remember to:
- Set up billing alerts
- Monitor costs daily
- Destroy resources when done

---

**Congratulations!** You've successfully deployed EKS manually and learned each component. 🎉
