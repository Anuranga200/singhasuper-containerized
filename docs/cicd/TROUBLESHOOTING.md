# CI/CD Troubleshooting Guide

## Quick Diagnosis

### Is the pipeline failing?

1. **Check the workflow run**: Go to Actions tab → Click on failed run
2. **Identify the failing job**: Look for red X
3. **Read the error logs**: Click on the job to see detailed logs
4. **Find the section below** that matches your error

---

## Common Issues and Solutions

### 1. Authentication & Permissions

#### Issue: "Error: Credentials could not be loaded"

**Symptoms**:
```
Error: Credentials could not be loaded, please check your action inputs: 
Could not load credentials from any providers
```

**Causes**:
- Missing or incorrect AWS credentials in GitHub secrets
- Expired AWS access keys
- Incorrect secret names

**Solutions**:

```bash
# Verify secrets exist in GitHub
# Go to: Settings → Secrets and variables → Actions

# Required secrets:
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION

# Test credentials locally
aws sts get-caller-identity --profile your-profile

# If expired, create new access keys
aws iam create-access-key --user-name github-actions-deployer

# Update GitHub secrets with new keys
```

**Prevention**:
- Set calendar reminder to rotate credentials every 90 days
- Use OIDC instead of long-lived credentials (see [01-AWS-SETUP.md](./01-AWS-SETUP.md))

---

#### Issue: "AccessDenied" when pushing to ECR

**Symptoms**:
```
Error: denied: User: arn:aws:iam::123456789012:user/github-actions-deployer 
is not authorized to perform: ecr:PutImage on resource
```

**Causes**:
- IAM policy missing required permissions
- Wrong ECR repository ARN in policy
- Policy not attached to user/role

**Solutions**:

```bash
# Check current IAM policies
aws iam list-attached-user-policies --user-name github-actions-deployer

# Verify policy has ECR permissions
aws iam get-policy-version \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/GitHubActionsECRPolicy \
  --version-id v1

# Required permissions:
# - ecr:GetAuthorizationToken
# - ecr:BatchCheckLayerAvailability
# - ecr:PutImage
# - ecr:InitiateLayerUpload
# - ecr:UploadLayerPart
# - ecr:CompleteLayerUpload

# Attach policy if missing
aws iam attach-user-policy \
  --user-name github-actions-deployer \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/GitHubActionsECRPolicy
```

---

### 2. Testing Issues

#### Issue: Tests pass locally but fail in CI

**Symptoms**:
```
FAIL src/components/MyComponent.test.tsx
  ● Test suite failed to run
    Cannot find module '@/lib/utils'
```

**Causes**:
- Path alias not configured in CI
- Environment variables missing
- Different Node.js versions
- Missing dependencies

**Solutions**:

```yaml
# In workflow file, ensure Node.js version matches local
- uses: actions/setup-node@v4
  with:
    node-version: '18'  # Match your local version

# Verify dependencies are installed
- run: npm ci  # Not npm install

# Check environment variables
- run: |
    echo "NODE_ENV=$NODE_ENV"
    echo "CI=$CI"
    npm test
```

```bash
# Test locally with same Node version
nvm use 18
npm ci
npm test

# Check for missing dependencies
npm ls

# Verify path aliases in tsconfig.json
cat tsconfig.json | grep paths
```

**Prevention**:
- Use `npm ci` instead of `npm install` in CI
- Document required Node.js version in README
- Use `.nvmrc` file to specify Node version

---

#### Issue: Backend tests fail with "ECONNREFUSED" to MySQL

**Symptoms**:
```
Error: connect ECONNREFUSED 127.0.0.1:3306
    at TCPConnectWrap.afterConnect [as oncomplete]
```

**Causes**:
- MySQL service not started
- Wrong host/port configuration
- MySQL not ready when tests start

**Solutions**:

```yaml
# In workflow file, ensure MySQL service is configured
services:
  mysql:
    image: mysql:8.0
    env:
      MYSQL_ROOT_PASSWORD: test_password
      MYSQL_DATABASE: singha_loyalty_test
      MYSQL_USER: test_user
      MYSQL_PASSWORD: test_password
    ports:
      - 3306:3306
    options: >-
      --health-cmd="mysqladmin ping --silent"
      --health-interval=10s
      --health-timeout=5s
      --health-retries=3

# Add wait step before tests
- name: Wait for MySQL
  run: |
    for i in {1..30}; do
      if mysqladmin ping -h 127.0.0.1 -u test_user -ptest_password --silent; then
        echo "MySQL is ready"
        break
      fi
      echo "Waiting for MySQL..."
      sleep 2
    done
```

**Prevention**:
- Always include health checks for services
- Add explicit wait steps before tests
- Use retry logic in database connection code

---

#### Issue: Test coverage below threshold

**Symptoms**:
```
ERROR: Coverage for lines (58.32%) does not meet global threshold (60%)
```

**Causes**:
- New code added without tests
- Tests not covering all branches
- Coverage threshold too high

**Solutions**:

```bash
# Generate coverage report locally
npm run test:coverage

# Open HTML report
open coverage/index.html  # macOS
start coverage/index.html  # Windows

# Identify uncovered lines (red in report)
# Write tests for uncovered code

# Temporarily lower threshold (not recommended)
# In vitest.config.js:
coverage: {
  lines: 55,  # Lower temporarily
}
```

**Prevention**:
- Write tests alongside new code
- Review coverage report before pushing
- Set up pre-commit hook to check coverage

---

### 3. Docker Build Issues

#### Issue: Docker build fails with "COPY failed"

**Symptoms**:
```
ERROR [stage-1 4/6] COPY --from=builder /app/node_modules ./node_modules
COPY failed: file not found in build context
```

**Causes**:
- Wrong build context
- Files excluded by .dockerignore
- Multi-stage build issue

**Solutions**:

```bash
# Check build context
docker build -t test:latest ./server

# Verify Dockerfile COPY paths
cat server/Dockerfile

# Check .dockerignore
cat server/.dockerignore

# Build with verbose output
docker build -t test:latest --progress=plain ./server

# Test multi-stage build locally
docker build -t test:builder --target builder ./server
docker build -t test:latest ./server
```

**Prevention**:
- Test Docker builds locally before pushing
- Keep .dockerignore minimal
- Use explicit paths in COPY commands

---

#### Issue: Docker image too large

**Symptoms**:
```
Image size: 850MB
ERROR: Image size exceeds 250MB threshold
```

**Causes**:
- Not using multi-stage builds
- Including dev dependencies
- Large base image
- Not cleaning up in Dockerfile

**Solutions**:

```dockerfile
# Use multi-stage build
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY ./src ./src
# Don't copy node_modules again!

# Use alpine base image (smaller)
FROM node:18-alpine  # ~40MB
# Instead of
FROM node:18  # ~900MB

# Clean up in same layer
RUN npm ci --only=production && \
    npm cache clean --force && \
    rm -rf /tmp/*
```

```bash
# Analyze image layers
docker history your-image:latest

# Check image size
docker images | grep your-image

# Use dive to analyze layers
docker run --rm -it \
  -v /var/run/docker.sock:/var/run/docker.sock \
  wagoodman/dive:latest your-image:latest
```

**Prevention**:
- Always use multi-stage builds
- Use alpine base images
- Exclude dev dependencies
- Set image size threshold in CI

---

### 4. Security Scan Issues

#### Issue: Trivy scan fails with vulnerabilities

**Symptoms**:
```
Total: 15 (HIGH: 3, CRITICAL: 2)
ERROR: Vulnerabilities found, failing build
```

**Causes**:
- Outdated dependencies
- Vulnerable base image
- Known CVEs in packages

**Solutions**:

```bash
# Update dependencies
npm update
npm audit fix

# Update base image in Dockerfile
FROM node:18-alpine  # Use latest patch version

# Check specific vulnerability
npm audit

# If false positive, add to .trivyignore
echo "CVE-2023-12345" >> .trivyignore

# Scan locally
trivy image your-image:latest

# Get detailed report
trivy image --format json your-image:latest > report.json
```

**Prevention**:
- Enable Dependabot for automatic updates
- Regularly update dependencies
- Use specific image tags (not `latest`)
- Review security advisories weekly

---

#### Issue: npm audit fails with high severity vulnerabilities

**Symptoms**:
```
found 5 vulnerabilities (3 moderate, 2 high)
ERROR: npm audit failed
```

**Causes**:
- Outdated packages
- Transitive dependencies with vulnerabilities
- No fix available yet

**Solutions**:

```bash
# Try automatic fix
npm audit fix

# Force fix (may break things)
npm audit fix --force

# Check what's vulnerable
npm audit --json

# Update specific package
npm update package-name

# If no fix available, check if you can upgrade
npm outdated

# Temporarily allow (not recommended)
npm audit --audit-level=critical  # Only fail on critical
```

**Prevention**:
- Run `npm audit` before every commit
- Enable Dependabot
- Review dependencies before adding
- Keep dependencies up to date

---

### 5. Deployment Issues

#### Issue: ECS deployment hangs or times out

**Symptoms**:
```
Waiting for service stability...
ERROR: Timeout waiting for service to become stable
```

**Causes**:
- Health check failing
- Insufficient resources (CPU/memory)
- Image pull errors
- Security group blocking traffic
- Task definition errors

**Solutions**:

```bash
# Check service events
aws ecs describe-services \
  --cluster your-cluster \
  --services your-service \
  --query 'services[0].events[0:10]'

# Check task status
aws ecs list-tasks \
  --cluster your-cluster \
  --service your-service

aws ecs describe-tasks \
  --cluster your-cluster \
  --tasks TASK_ARN

# Check task logs
aws logs tail /ecs/your-service --follow

# Common issues:

# 1. Health check failing
# Fix: Check health endpoint returns 200
curl https://your-api.com/health

# 2. Insufficient resources
# Fix: Increase task CPU/memory in task definition

# 3. Image pull error
# Fix: Verify image exists in ECR
aws ecr describe-images \
  --repository-name your-repo \
  --image-ids imageTag=your-tag

# 4. Security group
# Fix: Verify security group allows traffic
aws ec2 describe-security-groups \
  --group-ids sg-xxxxx
```

**Prevention**:
- Test health endpoint before deploying
- Monitor ECS service metrics
- Set appropriate timeouts
- Use CloudWatch alarms

---

#### Issue: Deployment succeeds but application doesn't work

**Symptoms**:
```
Deployment completed successfully
But: Application returns 500 errors
```

**Causes**:
- Environment variables not set
- Database migration not run
- Configuration errors
- Missing secrets

**Solutions**:

```bash
# Check task definition environment variables
aws ecs describe-task-definition \
  --task-definition your-task \
  --query 'taskDefinition.containerDefinitions[0].environment'

# Check application logs
aws logs tail /ecs/your-service --follow --since 10m

# Common issues:

# 1. Missing environment variables
# Fix: Add to task definition or use AWS Secrets Manager

# 2. Database migration not run
# Fix: Run migration in entrypoint script or separate task

# 3. Wrong configuration
# Fix: Verify all config values in task definition

# Test locally with same environment
docker run -e DATABASE_URL=xxx -e JWT_SECRET=yyy your-image:latest
```

**Prevention**:
- Use smoke tests after deployment
- Validate environment variables in code
- Log configuration on startup (without secrets!)
- Use AWS Secrets Manager for sensitive data

---

### 6. Performance Issues

#### Issue: Pipeline takes too long (> 15 minutes)

**Symptoms**:
```
Total pipeline time: 18 minutes
Expected: < 10 minutes
```

**Causes**:
- No caching
- Sequential job execution
- Slow tests
- Large Docker images

**Solutions**:

```yaml
# Add npm caching
- uses: actions/cache@v4
  with:
    path: |
      ~/.npm
      node_modules
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}

# Add Docker layer caching
- uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max

# Run jobs in parallel
jobs:
  test-frontend:
    needs: lint
  test-backend:
    needs: lint
  security-scan:
    needs: lint  # All run in parallel

# Optimize tests
# - Use test.concurrent for independent tests
# - Mock external services
# - Use in-memory database for unit tests
```

**Prevention**:
- Monitor pipeline duration
- Optimize slow tests
- Use caching aggressively
- Profile and optimize bottlenecks

---

#### Issue: Cache not working

**Symptoms**:
```
Cache not found for input keys: linux-node-abc123
Downloading dependencies... (3 minutes)
```

**Causes**:
- Cache key changed
- Cache expired (7 days)
- Cache size limit exceeded (10GB)
- Wrong cache path

**Solutions**:

```yaml
# Check cache key
- uses: actions/cache@v4
  with:
    path: node_modules
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-node-  # Fallback

# Verify cache is being saved
# Check workflow logs for "Cache saved successfully"

# Clear cache if corrupted
# Go to: Actions → Caches → Delete cache
```

**Prevention**:
- Use stable cache keys
- Include restore-keys for fallback
- Monitor cache hit rate
- Keep cache size under limit

---

## Emergency Procedures

### Production is Down!

**Immediate Actions**:

1. **Rollback immediately**:
```bash
# Option 1: Revert commit
git revert HEAD
git push origin main

# Option 2: Manual ECS rollback
aws ecs update-service \
  --cluster production-cluster \
  --service backend-service \
  --task-definition previous-task-def:10 \
  --force-new-deployment

# Option 3: Re-run previous successful workflow
# Go to Actions → Find last successful run → Re-run jobs
```

2. **Notify team**:
```bash
# Post in Slack
"🚨 Production incident - Rolling back deployment"
```

3. **Investigate**:
```bash
# Check logs
aws logs tail /ecs/production-service --follow --since 30m

# Check service events
aws ecs describe-services \
  --cluster production-cluster \
  --services backend-service

# Check task status
aws ecs describe-tasks \
  --cluster production-cluster \
  --tasks $(aws ecs list-tasks --cluster production-cluster --service backend-service --query 'taskArns[0]' --output text)
```

4. **Fix and redeploy**:
```bash
# Fix the issue
# Test locally
# Push fix
# Monitor deployment closely
```

---

### Pipeline Completely Broken

**Symptoms**: All workflows failing, can't deploy anything

**Actions**:

1. **Check GitHub Status**: https://www.githubstatus.com/
2. **Check AWS Status**: https://status.aws.amazon.com/
3. **Verify credentials haven't expired**
4. **Check for breaking changes in actions**:
   ```yaml
   # Pin action versions
   - uses: actions/checkout@v4  # Not @main
   ```
5. **Manual deployment as fallback**:
   ```bash
   # Build locally
   docker build -t backend:emergency ./server
   
   # Push to ECR
   aws ecr get-login-password | docker login --username AWS --password-stdin ECR_URL
   docker tag backend:emergency ECR_URL/backend:emergency
   docker push ECR_URL/backend:emergency
   
   # Update ECS
   aws ecs update-service \
     --cluster production-cluster \
     --service backend-service \
     --force-new-deployment
   ```

---

## Getting More Help

### Debugging Workflow Files

```bash
# Validate workflow syntax
# Use GitHub's workflow validator or:
yamllint .github/workflows/ci.yml

# Test workflow locally with act
act -j test-frontend

# Enable debug logging
# Add to workflow:
env:
  ACTIONS_STEP_DEBUG: true
  ACTIONS_RUNNER_DEBUG: true
```

### Useful Commands

```bash
# GitHub CLI commands
gh run list --limit 10
gh run view RUN_ID
gh run watch RUN_ID
gh run download RUN_ID

# AWS CLI commands
aws ecs describe-services --cluster CLUSTER --services SERVICE
aws ecs describe-tasks --cluster CLUSTER --tasks TASK_ARN
aws logs tail /ecs/SERVICE --follow
aws ecr describe-images --repository-name REPO

# Docker commands
docker logs CONTAINER_ID
docker inspect CONTAINER_ID
docker exec -it CONTAINER_ID sh
```

### Resources

- **GitHub Actions Docs**: https://docs.github.com/en/actions
- **GitHub Community**: https://github.community/
- **AWS Support**: https://console.aws.amazon.com/support/
- **Stack Overflow**: Tag with `github-actions`, `aws-ecs`, `docker`

### Contact

- **Internal**: Create issue in repository
- **Urgent**: Contact on-call engineer
- **AWS Issues**: AWS Support (if you have support plan)

---

**Remember**: When in doubt, rollback first, investigate later. Uptime is more important than debugging in production.
