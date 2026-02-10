# CI/CD Quick Reference Card

## 🚀 For Developers

### Daily Workflow

```bash
# 1. Create feature branch
git checkout -b feature/my-feature

# 2. Write code and tests
# ... make changes ...

# 3. Run tests locally
npm test                    # Frontend tests
cd server && npm test       # Backend tests

# 4. Run linting
npm run lint

# 5. Commit and push
git add .
git commit -m "feat: add new feature"
git push origin feature/my-feature

# 6. Create PR on GitHub
# CI will run automatically

# 7. After approval, merge to develop
# Staging deployment happens automatically

# 8. After testing in staging, merge to main
# Production deployment requires manual approval
```

### Running Tests Locally

```bash
# Frontend
npm test                    # Run once
npm run test:watch          # Watch mode
npm run test:coverage       # With coverage

# Backend
cd server
npm test                    # Run once
npm run test:watch          # Watch mode
npm run test:coverage       # With coverage
npm run test:integration    # Integration tests only
```

### Building Locally

```bash
# Frontend
npm run build               # Production build
npm run build:dev           # Development build

# Backend Docker
cd server
docker build -t backend:test .
docker run -p 3000:3000 backend:test
```

### Checking Pipeline Status

1. Go to GitHub repository
2. Click "Actions" tab
3. See workflow runs
4. Click on a run to see details
5. Click on a job to see logs

### Common CI/CD Commands

```bash
# Trigger manual deployment (if you have permissions)
# Go to Actions → Select workflow → Run workflow

# Check Docker image in ECR
aws ecr describe-images --repository-name singha-loyalty-backend --region us-east-1

# Check ECS service status
aws ecs describe-services --cluster your-cluster --services your-service --region us-east-1

# View ECS logs
aws logs tail /ecs/your-service --follow --region us-east-1
```

## 🔧 For DevOps Engineers

### Pipeline Files

```
.github/workflows/
├── ci.yml                  # Continuous Integration
├── cd-staging.yml          # Deploy to Staging
└── cd-production.yml       # Deploy to Production
```

### Workflow Triggers

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| CI | PR to main/develop, Push to feature/* | Validate code |
| CD Staging | Push to develop | Deploy to staging |
| CD Production | Push to main | Deploy to production |

### Key Jobs

**CI Workflow**:
1. `lint-and-format` - Code quality checks
2. `test-frontend` - Frontend tests
3. `test-backend` - Backend tests (with MySQL)
4. `security-scan` - npm audit + Trivy
5. `build-frontend` - Vite build
6. `build-backend` - Docker build

**CD Staging**:
1. Run CI workflow
2. `push-backend-ecr` - Push to ECR with staging tags
3. `deploy-ecs-staging` - Update ECS service
4. `smoke-tests` - Validate deployment

**CD Production**:
1. Run CI workflow
2. `push-backend-ecr-prod` - Push to ECR with production tags
3. `approval` - Manual approval gate
4. `deploy-ecs-production` - Update ECS service
5. `post-deploy-validation` - Comprehensive tests

### GitHub Secrets

**Repository Secrets**:
```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION
AWS_ACCOUNT_ID
ECR_REPOSITORY_BACKEND
ECR_REPOSITORY_FRONTEND
ECS_CLUSTER_STAGING
ECS_CLUSTER_PRODUCTION
ECS_SERVICE_BACKEND_STAGING
ECS_SERVICE_BACKEND_PRODUCTION
ECS_TASK_DEFINITION_BACKEND
```

**Environment Secrets** (staging/production):
```
DATABASE_URL
JWT_SECRET
API_BASE_URL
```

### Monitoring Commands

```bash
# Check GitHub Actions usage
gh api /repos/OWNER/REPO/actions/billing/usage

# List recent workflow runs
gh run list --limit 10

# View workflow run details
gh run view RUN_ID

# Download workflow logs
gh run download RUN_ID

# List ECR images
aws ecr list-images --repository-name REPO_NAME --region REGION

# Describe ECS service
aws ecs describe-services --cluster CLUSTER --services SERVICE

# View ECS task logs
aws logs tail /ecs/SERVICE_NAME --follow

# Check ECS deployment status
aws ecs describe-services --cluster CLUSTER --services SERVICE \
  --query 'services[0].deployments'
```

### Troubleshooting

#### Pipeline Fails at Lint Stage
```bash
# Run locally to see errors
npm run lint

# Auto-fix issues
npm run lint -- --fix
```

#### Tests Fail in CI but Pass Locally
```bash
# Check environment variables
cat .env.test

# Run tests with same Node version as CI
nvm use 18
npm test

# Check MySQL connection
mysql -h localhost -u test_user -p test_db
```

#### Docker Build Fails
```bash
# Build locally to see errors
cd server
docker build -t test:latest .

# Check build context
docker build -t test:latest --progress=plain .

# Test image
docker run -p 3000:3000 test:latest
```

#### ECS Deployment Hangs
```bash
# Check service events
aws ecs describe-services --cluster CLUSTER --services SERVICE \
  --query 'services[0].events[0:5]'

# Check task status
aws ecs list-tasks --cluster CLUSTER --service SERVICE
aws ecs describe-tasks --cluster CLUSTER --tasks TASK_ARN

# Check task logs
aws logs tail /ecs/SERVICE_NAME --since 10m
```

#### Rollback Deployment
```bash
# Option 1: Revert commit and push
git revert HEAD
git push origin main

# Option 2: Manual ECS rollback
aws ecs update-service \
  --cluster CLUSTER \
  --service SERVICE \
  --task-definition PREVIOUS_TASK_DEF \
  --force-new-deployment

# Option 3: Re-run previous successful workflow
# Go to Actions → Find successful run → Re-run jobs
```

### Performance Optimization

```bash
# Check cache hit rate
# Go to Actions → Workflow run → Check cache restore logs

# Analyze Docker image size
docker images | grep singha-loyalty

# Optimize Docker layers
docker history IMAGE_ID

# Check pipeline duration
gh run list --json durationMs --jq '.[].durationMs'
```

### Security

```bash
# Rotate AWS credentials
aws iam create-access-key --user-name github-actions-deployer
# Update GitHub secrets
# Delete old access key
aws iam delete-access-key --user-name github-actions-deployer --access-key-id OLD_KEY

# Scan for secrets in code
git secrets --scan

# Check security vulnerabilities
npm audit
cd server && npm audit

# Scan Docker image
trivy image IMAGE_NAME
```

## 📊 Metrics Dashboard

### Key Metrics to Track

1. **Deployment Frequency**: How often you deploy
   - Target: Multiple times per day
   - Track: GitHub Actions runs

2. **Lead Time for Changes**: Time from commit to production
   - Target: < 1 hour
   - Track: Commit timestamp to deployment timestamp

3. **Change Failure Rate**: % of deployments causing failure
   - Target: < 5%
   - Track: Failed deployments / Total deployments

4. **Mean Time to Recovery (MTTR)**: Time to recover from failure
   - Target: < 30 minutes
   - Track: Failure detection to fix deployed

5. **Test Coverage**: % of code covered by tests
   - Target: Frontend 70%, Backend 60%
   - Track: Coverage reports

6. **Pipeline Success Rate**: % of successful pipeline runs
   - Target: > 95%
   - Track: Successful runs / Total runs

### Viewing Metrics

```bash
# Deployment frequency (last 30 days)
gh run list --created ">$(date -d '30 days ago' +%Y-%m-%d)" --json conclusion \
  | jq '[.[] | select(.conclusion == "success")] | length'

# Pipeline success rate
gh run list --limit 100 --json conclusion \
  | jq '[.[] | select(.conclusion == "success")] | length'

# Average pipeline duration
gh run list --limit 50 --json durationMs \
  | jq '[.[].durationMs] | add / length / 1000 / 60'
```

## 🔗 Quick Links

- **GitHub Actions**: https://github.com/YOUR_ORG/YOUR_REPO/actions
- **AWS ECR Console**: https://console.aws.amazon.com/ecr/
- **AWS ECS Console**: https://console.aws.amazon.com/ecs/
- **Staging App**: https://staging.yourdomain.com
- **Production App**: https://yourdomain.com
- **Documentation**: [README.md](./README.md)

## 📞 Support

- **Pipeline Issues**: Create issue in repository
- **AWS Issues**: Contact DevOps team
- **Urgent Production Issues**: On-call engineer

---

**Pro Tip**: Bookmark this page for quick reference!
