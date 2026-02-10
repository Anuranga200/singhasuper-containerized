# GitHub Actions CI/CD Pipeline - Design Document

## 1. Architecture Overview

### 1.1 Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     GitHub Repository                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   Feature    │  │   Develop    │  │     Main     │          │
│  │   Branches   │  │   Branch     │  │   Branch     │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
└─────────┼──────────────────┼──────────────────┼─────────────────┘
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    GitHub Actions Workflows                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  CI Workflow (Pull Requests & Feature Branches)          │  │
│  │  • Lint → Test → Security Scan → Build                   │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  CD Workflow - Staging (Develop Branch)                  │  │
│  │  • CI Steps → Push to ECR → Deploy to Staging ECS        │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  CD Workflow - Production (Main Branch)                  │  │
│  │  • CI Steps → Push to ECR → Manual Approval → Deploy     │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Services                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │     ECR      │  │  ECS Staging │  │ ECS Production│          │
│  │  (Registry)  │  │   Cluster    │  │   Cluster     │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Workflow Files Structure

```
.github/
├── workflows/
│   ├── ci.yml                    # Continuous Integration
│   ├── cd-staging.yml            # Deploy to Staging
│   ├── cd-production.yml         # Deploy to Production
│   └── reusable-build.yml        # Reusable build workflow
├── actions/
│   ├── setup-node/               # Custom action for Node setup
│   └── docker-build/             # Custom action for Docker build
└── dependabot.yml                # Dependency updates
```

## 2. Detailed Workflow Design

### 2.1 CI Workflow (ci.yml)

**Purpose**: Validate code quality, run tests, and build artifacts for PRs and feature branches

**Triggers**:
- Pull requests to `main` or `develop`
- Push to feature branches (`feature/*`, `bugfix/*`, `hotfix/*`)

**Jobs**:

#### Job 1: Code Quality (lint-and-format)
```yaml
Runs on: ubuntu-latest
Timeout: 5 minutes
Steps:
  1. Checkout code
  2. Setup Node.js 18
  3. Cache npm dependencies
  4. Install dependencies (npm ci)
  5. Run ESLint (frontend)
  6. Run TypeScript type check
  7. Run Prettier format check
  8. Upload lint results as artifact
```

**Reasoning**: Catching code quality issues early prevents technical debt and ensures consistent code style across the team.

#### Job 2: Frontend Tests (test-frontend)
```yaml
Runs on: ubuntu-latest
Timeout: 10 minutes
Depends on: lint-and-format
Steps:
  1. Checkout code
  2. Setup Node.js 18
  3. Restore npm cache
  4. Install dependencies
  5. Run Vitest tests with coverage
  6. Generate coverage report
  7. Upload coverage to Codecov (optional)
  8. Fail if coverage < 70%
  9. Upload test results as artifact
```

**Reasoning**: Frontend tests validate UI components and business logic. Coverage threshold ensures adequate test coverage.

#### Job 3: Backend Tests (test-backend)
```yaml
Runs on: ubuntu-latest
Timeout: 10 minutes
Depends on: lint-and-format
Services:
  mysql:
    image: mysql:8.0
    env:
      MYSQL_ROOT_PASSWORD: test_password
      MYSQL_DATABASE: test_db
    ports:
      - 3306:3306
    options: >-
      --health-cmd="mysqladmin ping"
      --health-interval=10s
      --health-timeout=5s
      --health-retries=3
Steps:
  1. Checkout code
  2. Setup Node.js 18
  3. Restore npm cache
  4. Install dependencies (server/)
  5. Wait for MySQL to be ready
  6. Run database migrations (test DB)
  7. Run Jest/Vitest tests with coverage
  8. Generate coverage report
  9. Fail if coverage < 60%
  10. Upload test results as artifact
```

**Reasoning**: Backend tests require a real database for integration tests. Using GitHub Actions services provides isolated test environment.

#### Job 4: Security Scan (security-scan)
```yaml
Runs on: ubuntu-latest
Timeout: 10 minutes
Runs in parallel with tests
Steps:
  1. Checkout code
  2. Setup Node.js 18
  3. Run npm audit (frontend)
  4. Run npm audit (backend)
  5. Run Trivy filesystem scan
  6. Generate security report
  7. Fail on critical vulnerabilities
  8. Upload security report as artifact
```

**Reasoning**: Early security scanning prevents vulnerable dependencies from reaching production. Trivy catches OS-level vulnerabilities.

#### Job 5: Build Frontend (build-frontend)
```yaml
Runs on: ubuntu-latest
Timeout: 10 minutes
Depends on: [test-frontend, security-scan]
Steps:
  1. Checkout code
  2. Setup Node.js 18
  3. Restore npm cache
  4. Install dependencies
  5. Build production bundle (npm run build)
  6. Verify build output exists
  7. Upload build artifact
  8. Calculate bundle size
  9. Comment bundle size on PR
```

**Reasoning**: Validates that production build succeeds. Bundle size tracking prevents performance regressions.

#### Job 6: Build Backend Docker (build-backend)
```yaml
Runs on: ubuntu-latest
Timeout: 15 minutes
Depends on: [test-backend, security-scan]
Steps:
  1. Checkout code
  2. Setup Docker Buildx
  3. Build Docker image (no push)
  4. Run Trivy image scan
  5. Test image (docker run health check)
  6. Calculate image size
  7. Fail if image > 250MB
  8. Upload image scan results
```

**Reasoning**: Validates Docker build without pushing to ECR. Image size limit ensures efficient deployments.

### 2.2 CD Staging Workflow (cd-staging.yml)

**Purpose**: Deploy to staging environment on develop branch

**Triggers**:
- Push to `develop` branch
- Manual workflow_dispatch

**Jobs**:

#### Job 1: Run CI Checks
```yaml
Uses: ./.github/workflows/ci.yml
```

**Reasoning**: Reuse CI workflow to avoid duplication. Ensures all checks pass before deployment.

#### Job 2: Build and Push Backend to ECR
```yaml
Runs on: ubuntu-latest
Timeout: 20 minutes
Depends on: CI checks pass
Environment: staging
Steps:
  1. Checkout code
  2. Configure AWS credentials
  3. Login to Amazon ECR
  4. Setup Docker Buildx
  5. Extract metadata (tags, labels)
  6. Build and push Docker image
     Tags: 
       - staging-latest
       - staging-${{ github.sha }}
       - staging-${{ github.run_number }}
  7. Scan image with Trivy
  8. Output image digest
```

**Reasoning**: Multi-tag strategy enables rollback and tracking. Scanning after push ensures ECR images are secure.

#### Job 3: Build and Push Frontend to S3/ECR
```yaml
Runs on: ubuntu-latest
Timeout: 15 minutes
Depends on: CI checks pass
Environment: staging
Steps:
  1. Checkout code
  2. Setup Node.js 18
  3. Install dependencies
  4. Build with staging env vars
  5. Configure AWS credentials
  6. Sync to S3 bucket (if using S3)
  7. OR build Docker image and push to ECR
  8. Invalidate CloudFront cache
```

**Reasoning**: Frontend can be deployed to S3+CloudFront or as Docker container. Flexible approach.

#### Job 4: Deploy Backend to ECS
```yaml
Runs on: ubuntu-latest
Timeout: 10 minutes
Depends on: Build and Push Backend
Environment: staging
Steps:
  1. Configure AWS credentials
  2. Download task definition
  3. Update task definition with new image
  4. Register new task definition
  5. Update ECS service
  6. Wait for service stability (max 10 min)
  7. Verify deployment health
  8. Send Slack notification (optional)
```

**Reasoning**: ECS rolling update ensures zero-downtime deployment. Health check validation prevents bad deployments.

#### Job 5: Run Smoke Tests
```yaml
Runs on: ubuntu-latest
Timeout: 5 minutes
Depends on: Deploy Backend to ECS
Steps:
  1. Wait 30 seconds for service warmup
  2. Test health endpoint
  3. Test critical API endpoints
  4. Verify database connectivity
  5. Check application logs
  6. Rollback if tests fail
```

**Reasoning**: Smoke tests validate deployment success. Automated rollback prevents broken staging environment.

### 2.3 CD Production Workflow (cd-production.yml)

**Purpose**: Deploy to production with manual approval

**Triggers**:
- Push to `main` branch
- Manual workflow_dispatch with version tag

**Jobs**:

#### Job 1: Run CI Checks
```yaml
Uses: ./.github/workflows/ci.yml
```

#### Job 2: Build and Push to ECR (Production)
```yaml
Similar to staging but with production tags:
  - production-latest
  - production-v${{ github.ref_name }}
  - production-${{ github.sha }}
```

#### Job 3: Manual Approval Gate
```yaml
Runs on: ubuntu-latest
Environment: production (requires approval)
Steps:
  1. Display deployment summary
  2. Wait for manual approval
  3. Log approval details
```

**Reasoning**: Production deployments require human oversight. GitHub Environments provide approval workflow.

#### Job 4: Deploy to Production ECS
```yaml
Same as staging deployment but:
  - Uses production ECS cluster
  - Longer stability wait (15 min)
  - More comprehensive health checks
  - Automated rollback on failure
```

#### Job 5: Post-Deployment Validation
```yaml
Runs on: ubuntu-latest
Timeout: 10 minutes
Steps:
  1. Run comprehensive smoke tests
  2. Verify all critical endpoints
  3. Check error rates in logs
  4. Validate database migrations
  5. Test authentication flows
  6. Send success notification
  7. Create GitHub release
  8. Tag Docker images as stable
```

**Reasoning**: Thorough validation ensures production stability. Release creation provides deployment history.

## 3. Reusable Workflows

### 3.1 Reusable Build Workflow (reusable-build.yml)

**Purpose**: DRY principle - shared build logic

```yaml
Inputs:
  - environment (staging/production)
  - image-tag
  - ecr-repository
  - run-tests (boolean)
  
Outputs:
  - image-digest
  - image-tags
  
Jobs:
  - Build Docker image
  - Scan with Trivy
  - Push to ECR
  - Output metadata
```

**Reasoning**: Reduces duplication between staging and production workflows. Easier to maintain and update.

## 4. Security Design

### 4.1 AWS Authentication

**Option 1: IAM User with Access Keys (Current)**
```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: ${{ secrets.AWS_REGION }}
```

**Option 2: OIDC (Recommended for Production)**
```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/GitHubActionsRole
    aws-region: ${{ secrets.AWS_REGION }}
```

**Reasoning**: OIDC eliminates long-lived credentials, reducing security risk. Requires one-time AWS IAM setup.

### 4.2 IAM Policy (Least Privilege)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition",
        "ecs:RegisterTaskDefinition",
        "ecs:UpdateService"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": "arn:aws:iam::*:role/ecsTaskExecutionRole"
    }
  ]
}
```

**Reasoning**: Minimal permissions required for ECR push and ECS deployment. Prevents unauthorized access.

### 4.3 Secrets Management

**GitHub Secrets (Encrypted at Rest)**:
```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION
AWS_ACCOUNT_ID
ECR_REPOSITORY_BACKEND
ECR_REPOSITORY_FRONTEND
DATABASE_URL_STAGING
DATABASE_URL_PRODUCTION
JWT_SECRET_STAGING
JWT_SECRET_PRODUCTION
SLACK_WEBHOOK_URL (optional)
```

**Environment-Specific Secrets**:
- Use GitHub Environments (staging, production)
- Each environment has its own secrets
- Production requires approval

**Reasoning**: Environment isolation prevents accidental production deployments with staging credentials.

### 4.4 Vulnerability Scanning Strategy

**Trivy Scanning Levels**:
1. **Filesystem Scan** (CI): Scans source code dependencies
2. **Image Scan** (Build): Scans Docker image layers
3. **Registry Scan** (Post-Push): Scans images in ECR

**Severity Thresholds**:
- **CRITICAL**: Block deployment immediately
- **HIGH**: Block deployment, require manual override
- **MEDIUM**: Warn but allow deployment
- **LOW**: Log only

**Reasoning**: Multi-layer scanning catches vulnerabilities at different stages. Severity-based blocking balances security and velocity.

## 5. Performance Optimization

### 5.1 Caching Strategy

#### NPM Dependencies Cache
```yaml
- uses: actions/cache@v4
  with:
    path: |
      ~/.npm
      node_modules
      server/node_modules
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-node-
```

**Impact**: Reduces npm install time from 2-3 minutes to 30 seconds

#### Docker Layer Cache
```yaml
- uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

**Impact**: Reduces Docker build time from 5 minutes to 1-2 minutes

#### Build Artifact Cache
```yaml
- uses: actions/cache@v4
  with:
    path: dist
    key: build-${{ github.sha }}
```

**Impact**: Reuse build artifacts across jobs

**Reasoning**: Caching is critical for fast feedback loops. GitHub Actions cache is free and reliable.

### 5.2 Parallel Job Execution

```yaml
Jobs run in parallel:
  - lint-and-format
  - test-frontend (after lint)
  - test-backend (after lint)
  - security-scan (parallel with tests)
  
Sequential jobs:
  - build-frontend (after test-frontend)
  - build-backend (after test-backend)
  - deploy (after all builds)
```

**Reasoning**: Parallel execution reduces total pipeline time from 30 minutes to 10 minutes.

### 5.3 Conditional Job Execution

```yaml
- name: Run expensive test
  if: github.event_name == 'push' && github.ref == 'refs/heads/main'
```

**Use Cases**:
- Skip deployment jobs on PRs
- Run integration tests only on main/develop
- Skip security scans on documentation changes

**Reasoning**: Saves GitHub Actions minutes and speeds up feedback for developers.

## 6. Testing Strategy

### 6.1 Backend Testing Setup (NEW)

**Test Framework**: Vitest (consistent with frontend)

**Test Structure**:
```
server/
├── src/
│   ├── controllers/
│   │   ├── adminController.js
│   │   └── adminController.test.js
│   ├── middleware/
│   │   ├── auth.js
│   │   └── auth.test.js
│   └── routes/
│       ├── admin.js
│       └── admin.test.js
└── vitest.config.js
```

**Test Types**:
1. **Unit Tests**: Test individual functions and middleware
2. **Integration Tests**: Test API endpoints with test database
3. **Contract Tests**: Validate API responses match OpenAPI spec

**Test Database Strategy**:
- Use GitHub Actions MySQL service
- Run migrations before tests
- Seed test data
- Clean up after tests

**Coverage Requirements**:
- Overall: 60% minimum
- Controllers: 70% minimum
- Middleware: 80% minimum
- Routes: 60% minimum

### 6.2 Frontend Testing Enhancement

**Current State**: Basic Vitest setup with example test

**Enhancements Needed**:
1. Component tests for all pages
2. Hook tests for custom hooks
3. Integration tests for API calls
4. Accessibility tests with jest-axe

**Test Coverage Goals**:
- Components: 75%
- Hooks: 80%
- Utils: 90%
- Overall: 70%

### 6.3 Smoke Tests

**Purpose**: Validate deployment success

**Tests**:
```javascript
// Health check
GET /health → 200 OK

// Database connectivity
GET /api/admin/customers → 200 OK (with auth)

// Authentication
POST /api/admin/login → 200 OK (valid creds)
POST /api/admin/login → 401 (invalid creds)

// CORS
OPTIONS /api/admin/customers → 200 OK
```

**Reasoning**: Smoke tests catch deployment issues immediately. Fast execution (< 30 seconds).

## 7. Monitoring and Observability

### 7.1 Pipeline Metrics

**Tracked Metrics**:
- Build duration (per job)
- Test execution time
- Deployment frequency
- Failure rate
- Mean time to recovery (MTTR)

**Implementation**:
```yaml
- name: Track metrics
  run: |
    echo "build_duration_seconds=${{ job.duration }}" >> $GITHUB_OUTPUT
    echo "test_count=${{ steps.test.outputs.test_count }}" >> $GITHUB_OUTPUT
```

### 7.2 Notifications

**Slack Integration** (Optional):
```yaml
- name: Notify Slack
  if: failure()
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK_URL }}
    payload: |
      {
        "text": "❌ Deployment failed: ${{ github.repository }}",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "*Workflow*: ${{ github.workflow }}\n*Status*: Failed\n*Branch*: ${{ github.ref }}"
            }
          }
        ]
      }
```

### 7.3 Deployment Tracking

**GitHub Deployments API**:
```yaml
- name: Create deployment
  uses: chrnorm/deployment-action@v2
  with:
    token: ${{ github.token }}
    environment: production
    ref: ${{ github.sha }}
```

**Reasoning**: GitHub Deployments provide deployment history and integration with monitoring tools.

## 8. Rollback Strategy

### 8.1 Automated Rollback

**Trigger Conditions**:
- Health check fails after deployment
- Error rate > 5% in first 5 minutes
- Smoke tests fail

**Implementation**:
```yaml
- name: Rollback on failure
  if: failure()
  run: |
    aws ecs update-service \
      --cluster ${{ env.ECS_CLUSTER }} \
      --service ${{ env.ECS_SERVICE }} \
      --task-definition ${{ env.PREVIOUS_TASK_DEF }} \
      --force-new-deployment
```

### 8.2 Manual Rollback

**Process**:
1. Identify previous stable image tag
2. Trigger workflow_dispatch with previous tag
3. Deploy previous version
4. Verify rollback success

**Reasoning**: Automated rollback prevents prolonged outages. Manual rollback provides control for complex issues.

## 9. Cost Optimization

### 9.1 GitHub Actions Minutes

**Free Tier**: 2000 minutes/month (private repos)

**Estimated Usage**:
- CI pipeline: 8 minutes × 20 runs/day = 160 min/day = 4800 min/month
- CD staging: 12 minutes × 5 runs/day = 60 min/day = 1800 min/month
- CD production: 15 minutes × 2 runs/day = 30 min/day = 900 min/month

**Total**: ~7500 minutes/month

**Cost**: ~$270/month (at $0.008/minute for private repos)

**Optimization Strategies**:
1. Use caching aggressively
2. Skip unnecessary jobs on PRs
3. Use self-hosted runners for heavy workloads
4. Optimize Docker builds

### 9.2 AWS Costs

**ECR Storage**: ~$0.10/GB/month
- Estimated: 10 images × 200MB = 2GB = $0.20/month

**Data Transfer**: $0.09/GB (out to internet)
- Estimated: 50 deployments × 200MB = 10GB = $0.90/month

**Total AWS**: ~$1.10/month (negligible)

## 10. Implementation Phases

### Phase 1: Foundation (Week 1)
- Setup GitHub Actions workflows directory
- Create CI workflow with linting and basic tests
- Setup GitHub secrets
- Test CI workflow on feature branch

### Phase 2: Testing Infrastructure (Week 1-2)
- Setup backend testing with Vitest
- Add MySQL service to CI workflow
- Write initial backend tests (controllers, middleware)
- Achieve 60% backend coverage

### Phase 3: Security Scanning (Week 2)
- Integrate Trivy scanning
- Add npm audit checks
- Setup vulnerability reporting
- Configure severity thresholds

### Phase 4: Docker Build (Week 2-3)
- Create Docker build job
- Implement layer caching
- Add image size validation
- Test Docker image locally

### Phase 5: ECR Integration (Week 3)
- Setup AWS credentials in GitHub
- Create ECR push workflow
- Test image push to ECR
- Verify image tags

### Phase 6: ECS Deployment (Week 3-4)
- Create staging deployment workflow
- Test deployment to staging ECS
- Add health checks and smoke tests
- Implement rollback logic

### Phase 7: Production Pipeline (Week 4)
- Create production workflow with approval
- Test end-to-end production deployment
- Document deployment process
- Train team on new pipeline

### Phase 8: Monitoring & Optimization (Week 4-5)
- Add Slack notifications
- Setup deployment tracking
- Optimize caching and parallelization
- Document metrics and SLOs

## 11. Success Criteria

### 11.1 Technical Criteria
- ✅ All tests pass in CI
- ✅ No critical security vulnerabilities
- ✅ Docker image < 250MB
- ✅ Pipeline execution < 10 minutes
- ✅ Zero-downtime deployments
- ✅ Automated rollback works

### 11.2 Business Criteria
- ✅ Deployment frequency increases 10x
- ✅ Lead time for changes < 1 hour
- ✅ Change failure rate < 5%
- ✅ MTTR < 30 minutes
- ✅ Developer satisfaction improves

## 12. Documentation Requirements

### 12.1 README Updates
- Add CI/CD badges
- Document deployment process
- Link to workflow files
- Explain branch strategy

### 12.2 Runbooks
- Deployment runbook
- Rollback procedures
- Troubleshooting guide
- Secrets rotation guide

### 12.3 Architecture Diagrams
- Pipeline flow diagram
- AWS infrastructure diagram
- Security architecture
- Deployment process flowchart
