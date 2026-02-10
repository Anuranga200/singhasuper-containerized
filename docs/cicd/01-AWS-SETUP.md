# AWS Setup for GitHub Actions CI/CD

## Option B: OIDC (Recommended for Production - More Secure)

### Why OIDC?
- **No long-lived credentials**: Temporary tokens only
- **Automatic rotation**: Tokens expire after use
- **Better security posture**: No secrets to leak
- **AWS best practice**: Recommended by AWS

### Setup Steps

#### 1. Create OIDC Provider in AWS

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

#### 2. Create IAM Role for GitHub Actions

Create file `github-actions-trust-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/YOUR_REPO:*"
        }
      }
    }
  ]
}
```

**Replace**:
- `ACCOUNT_ID`: Your AWS account ID
- `YOUR_GITHUB_ORG`: Your GitHub organization or username
- `YOUR_REPO`: Your repository name

Create the role:

```bash
aws iam create-role \
  --role-name GitHubActionsRole \
  --assume-role-policy-document file://github-actions-trust-policy.json

aws iam attach-role-policy \
  --role-name GitHubActionsRole \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/GitHubActionsECRPolicy
```

#### 3. Update GitHub Workflows to Use OIDC

In your workflow files, replace:

```yaml
# OLD (Access Keys)
- uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: ${{ secrets.AWS_REGION }}
```

With:

```yaml
# NEW (OIDC)
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/GitHubActionsRole
    aws-region: ${{ secrets.AWS_REGION }}
```

**Note**: You'll still need `AWS_ACCOUNT_ID` and `AWS_REGION` as GitHub secrets, but no access keys!

## Verify AWS Resources

Before proceeding, verify your AWS infrastructure is ready:

### 1. Check ECR Repositories

```bash
# List ECR repositories
aws ecr describe-repositories --region us-east-1

# Expected output: You should see your backend and frontend repositories
```

If repositories don't exist, create them:

```bash
aws ecr create-repository --repository-name singha-loyalty-backend --region us-east-1
aws ecr create-repository --repository-name singha-loyalty-frontend --region us-east-1
```

### 2. Check ECS Clusters

```bash
# List ECS clusters
aws ecs list-clusters --region us-east-1

# Describe specific cluster
aws ecs describe-clusters --clusters your-cluster-name --region us-east-1
```

### 3. Check ECS Services

```bash
# List services in cluster
aws ecs list-services --cluster your-cluster-name --region us-east-1

# Describe specific service
aws ecs describe-services \
  --cluster your-cluster-name \
  --services your-service-name \
  --region us-east-1
```

### 4. Check Task Definitions

```bash
# List task definition families
aws ecs list-task-definition-families --region us-east-1

# Describe latest task definition
aws ecs describe-task-definition \
  --task-definition your-task-family:latest \
  --region us-east-1
```

## Configure GitHub Secrets

Navigate to: Repository Settings → Secrets and variables → Actions → New repository secret

### Required Repository Secrets

```yaml
AWS_ACCESS_KEY_ID: AKIA... (if using access keys)
AWS_SECRET_ACCESS_KEY: ... (if using access keys)
AWS_REGION: us-east-1
AWS_ACCOUNT_ID: 123456789012
ECR_REPOSITORY_BACKEND: singha-loyalty-backend
ECR_REPOSITORY_FRONTEND: singha-loyalty-frontend
ECS_CLUSTER_STAGING: your-staging-cluster
ECS_CLUSTER_PRODUCTION: your-production-cluster
ECS_SERVICE_BACKEND_STAGING: backend-staging-service
ECS_SERVICE_BACKEND_PRODUCTION: backend-production-service
ECS_TASK_DEFINITION_BACKEND: backend-task-family
```

### Environment-Specific Secrets (staging environment)

```yaml
DATABASE_URL: mysql://user:pass@staging-db.amazonaws.com:3306/dbname
JWT_SECRET: your-staging-jwt-secret-min-32-chars
API_BASE_URL: https://staging-api.yourdomain.com
```

### Environment-Specific Secrets (production environment)

```yaml
DATABASE_URL: mysql://user:pass@production-db.amazonaws.com:3306/dbname
JWT_SECRET: your-production-jwt-secret-min-32-chars-DIFFERENT-FROM-STAGING
API_BASE_URL: https://api.yourdomain.com
```

## Security Best Practices

### 1. Rotate Credentials Regularly

Set calendar reminders:
- **Access Keys**: Rotate every 90 days
- **JWT Secrets**: Rotate every 180 days
- **Database Passwords**: Rotate every 90 days

### 2. Use AWS Secrets Manager (Advanced)

Instead of storing secrets in GitHub, store them in AWS Secrets Manager and retrieve them in workflows:

```yaml
- name: Get secrets from AWS Secrets Manager
  run: |
    SECRET=$(aws secretsmanager get-secret-value --secret-id prod/database/password --query SecretString --output text)
    echo "::add-mask::$SECRET"
    echo "DATABASE_PASSWORD=$SECRET" >> $GITHUB_ENV
```

### 3. Enable AWS CloudTrail

Monitor all API calls made by GitHub Actions:

```bash
aws cloudtrail create-trail \
  --name github-actions-audit \
  --s3-bucket-name your-cloudtrail-bucket
```

### 4. Set Up AWS Budgets

Prevent surprise bills:

```bash
aws budgets create-budget \
  --account-id ACCOUNT_ID \
  --budget file://budget.json \
  --notifications-with-subscribers file://notifications.json
```

## Troubleshooting AWS Issues

### Issue: "AccessDenied" when pushing to ECR

**Solution**: Verify IAM policy includes `ecr:GetAuthorizationToken` and repository-specific permissions.

```bash
# Test ECR authentication
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
```

### Issue: "Unable to assume role" with OIDC

**Solution**: Check trust policy allows your repository:

```bash
aws iam get-role --role-name GitHubActionsRole --query 'Role.AssumeRolePolicyDocument'
```

Verify the `sub` condition matches: `repo:YOUR_ORG/YOUR_REPO:*`

### Issue: ECS deployment hangs

**Solution**: Check ECS service events:

```bash
aws ecs describe-services \
  --cluster your-cluster \
  --services your-service \
  --query 'services[0].events[0:5]'
```

Common causes:
- Task definition references non-existent image
- Insufficient resources (CPU/memory)
- Health check failing
- Security group blocking traffic

## Next Steps

Once AWS setup is complete:
1. ✅ IAM user/role created with least privilege
2. ✅ ECR repositories exist
3. ✅ ECS clusters and services running
4. ✅ GitHub secrets configured
5. ✅ Verified access with AWS CLI

Proceed to: [Backend Testing Infrastructure](./02-BACKEND-TESTING.md)
