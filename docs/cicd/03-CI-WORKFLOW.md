# Phase 3: CI Workflow Implementation

## Overview

The CI (Continuous Integration) workflow is the foundation of your pipeline. It runs on every push and pull request to validate code quality, run tests, and ensure security before any deployment.

## Workflow Architecture

```
CI Workflow Trigger (PR or Push)
        │
        ▼
┌─────────────────┐
│ Lint & Format   │ (2 min)
└────────┬────────┘
         │
         ├──────────┬──────────┬──────────┐
         ▼          ▼          ▼          ▼
    ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
    │Frontend│ │Backend │ │Security│ │ Build  │
    │ Tests  │ │ Tests  │ │  Scan  │ │Frontend│
    │(3 min) │ │(4 min) │ │(3 min) │ │(2 min) │
    └────┬───┘ └────┬───┘ └────┬───┘ └────┬───┘
         │          │          │          │
         └──────────┴──────────┴──────────┘
                    │
                    ▼
            ┌──────────────┐
            │Build Backend │
            │   Docker     │
            │   (3 min)    │
            └──────────────┘
```

## Step 1: Create CI Workflow File

Create `.github/workflows/ci.yml`:

```yaml
name: Continuous Integration

on:
  # Trigger on pull requests
  pull_request:
    branches:
      - main
      - develop
  
  # Trigger on pushes to feature branches
  push:
    branches:
      - 'feature/**'
      - 'bugfix/**'
      - 'hotfix/**'
  
  # Allow manual trigger
  workflow_dispatch:

# Cancel in-progress runs for same PR/branch
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

# Minimal permissions (security best practice)
permissions:
  contents: read
  pull-requests: write  # For PR comments
  security-events: write  # For security scanning

env:
  NODE_VERSION: '18'
  DOCKER_BUILDKIT: 1

jobs:
  # Job 1: Code Quality Checks
  lint-and-format:
    name: Lint and Format Check
    runs-on: ubuntu-latest
    timeout-minutes: 5
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
      
      - name: Cache npm dependencies
        uses: actions/cache@v4
        with:
          path: |
            ~/.npm
            node_modules
            server/node_modules
          key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            ${{ runner.os }}-node-
      
      - name: Install dependencies (root)
        run: npm ci
      
      - name: Install dependencies (server)
        run: cd server && npm ci
      
      - name: Run ESLint (frontend)
        run: npm run lint
      
      - name: Run TypeScript type check
        run: npx tsc --noEmit
      
      - name: Run Prettier format check
        run: npx prettier --check "src/**/*.{ts,tsx,js,jsx,json,css,md}"
      
      - name: Upload lint results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: lint-results
          path: |
            eslint-report.json
          retention-days: 7
```

**Why these settings?**
- `concurrency`: Cancels old runs when new commits pushed (saves minutes)
- `timeout-minutes`: Prevents stuck jobs from consuming minutes
- `permissions`: Minimal permissions (security best practice)
- `npm ci`: Faster and more reliable than `npm install`


## Step 2: Add Frontend Test Job

Add to `.github/workflows/ci.yml`:

```yaml
  # Job 2: Frontend Tests
  test-frontend:
    name: Frontend Tests
    runs-on: ubuntu-latest
    needs: lint-and-format
    timeout-minutes: 10
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
      
      - name: Restore npm cache
        uses: actions/cache@v4
        with:
          path: |
            ~/.npm
            node_modules
          key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            ${{ runner.os }}-node-
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run tests with coverage
        run: npm run test:coverage
      
      - name: Check coverage threshold
        run: |
          COVERAGE=$(jq '.total.lines.pct' coverage/coverage-summary.json)
          echo "Coverage: $COVERAGE%"
          if (( $(echo "$COVERAGE < 70" | bc -l) )); then
            echo "❌ Coverage below 70%"
            exit 1
          fi
          echo "✅ Coverage meets threshold"
      
      - name: Upload coverage to Codecov (optional)
        if: always()
        uses: codecov/codecov-action@v4
        with:
          files: ./coverage/lcov.info
          flags: frontend
          name: frontend-coverage
      
      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: frontend-test-results
          path: |
            coverage/
            test-results/
          retention-days: 7
      
      - name: Comment PR with coverage
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const coverage = JSON.parse(fs.readFileSync('coverage/coverage-summary.json', 'utf8'));
            const comment = `## 📊 Frontend Test Coverage
            
            | Metric | Coverage |
            |--------|----------|
            | Lines | ${coverage.total.lines.pct}% |
            | Statements | ${coverage.total.statements.pct}% |
            | Functions | ${coverage.total.functions.pct}% |
            | Branches | ${coverage.total.branches.pct}% |
            
            ${coverage.total.lines.pct >= 70 ? '✅' : '❌'} Coverage threshold: 70%`;
            
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: comment
            });
```

**Key Features**:
- Coverage threshold enforcement (fails if < 70%)
- PR comments with coverage report
- Codecov integration (optional)
- Test results uploaded as artifacts

## Step 3: Add Backend Test Job

Add to `.github/workflows/ci.yml`:

```yaml
  # Job 3: Backend Tests
  test-backend:
    name: Backend Tests
    runs-on: ubuntu-latest
    needs: lint-and-format
    timeout-minutes: 10
    
    # MySQL service container
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
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
      
      - name: Restore npm cache
        uses: actions/cache@v4
        with:
          path: |
            ~/.npm
            server/node_modules
          key: ${{ runner.os }}-node-server-${{ hashFiles('server/package-lock.json') }}
          restore-keys: |
            ${{ runner.os }}-node-server-
      
      - name: Install dependencies
        run: cd server && npm ci
      
      - name: Wait for MySQL to be ready
        run: |
          for i in {1..30}; do
            if mysqladmin ping -h 127.0.0.1 -u test_user -ptest_password --silent; then
              echo "✅ MySQL is ready"
              break
            fi
            echo "⏳ Waiting for MySQL... ($i/30)"
            sleep 2
          done
      
      - name: Run database migrations
        run: cd server && npm run migrate
        env:
          DB_HOST: 127.0.0.1
          DB_PORT: 3306
          DB_USER: test_user
          DB_PASSWORD: test_password
          DB_NAME: singha_loyalty_test
          NODE_ENV: test
      
      - name: Run tests with coverage
        run: cd server && npm run test:coverage
        env:
          DB_HOST: 127.0.0.1
          DB_PORT: 3306
          DB_USER: test_user
          DB_PASSWORD: test_password
          DB_NAME: singha_loyalty_test
          JWT_SECRET: test-jwt-secret-min-32-characters-long
          NODE_ENV: test
      
      - name: Check coverage threshold
        run: |
          cd server
          COVERAGE=$(jq '.total.lines.pct' coverage/coverage-summary.json)
          echo "Coverage: $COVERAGE%"
          if (( $(echo "$COVERAGE < 60" | bc -l) )); then
            echo "❌ Coverage below 60%"
            exit 1
          fi
          echo "✅ Coverage meets threshold"
      
      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: backend-test-results
          path: |
            server/coverage/
            server/test-results/
          retention-days: 7
```

**Key Features**:
- MySQL service container for integration tests
- Health check wait logic
- Database migrations before tests
- Coverage threshold enforcement (60%)
- Environment variables for test database

## Step 4: Add Security Scan Job

Add to `.github/workflows/ci.yml`:

```yaml
  # Job 4: Security Scanning
  security-scan:
    name: Security Scan
    runs-on: ubuntu-latest
    needs: lint-and-format
    timeout-minutes: 10
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
      
      - name: npm audit (frontend)
        run: |
          echo "🔍 Scanning frontend dependencies..."
          npm audit --audit-level=high --production || {
            echo "❌ High/Critical vulnerabilities found in frontend"
            exit 1
          }
      
      - name: npm audit (backend)
        run: |
          echo "🔍 Scanning backend dependencies..."
          cd server
          npm audit --audit-level=high --production || {
            echo "❌ High/Critical vulnerabilities found in backend"
            exit 1
          }
      
      - name: Run Trivy filesystem scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          severity: 'HIGH,CRITICAL'
          exit-code: '1'
          format: 'sarif'
          output: 'trivy-fs-results.sarif'
      
      - name: Upload Trivy results to GitHub Security
        if: always()
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-fs-results.sarif'
      
      - name: Generate security report
        if: always()
        run: |
          echo "# Security Scan Report" > security-report.md
          echo "" >> security-report.md
          echo "## npm audit (Frontend)" >> security-report.md
          npm audit --json > frontend-audit.json || true
          echo "\`\`\`json" >> security-report.md
          cat frontend-audit.json >> security-report.md
          echo "\`\`\`" >> security-report.md
          echo "" >> security-report.md
          echo "## npm audit (Backend)" >> security-report.md
          cd server && npm audit --json > ../backend-audit.json || true
          cd ..
          echo "\`\`\`json" >> security-report.md
          cat backend-audit.json >> security-report.md
          echo "\`\`\`" >> security-report.md
      
      - name: Upload security report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: security-report
          path: |
            security-report.md
            frontend-audit.json
            backend-audit.json
            trivy-fs-results.sarif
          retention-days: 30
```

**Key Features**:
- npm audit for both frontend and backend
- Trivy filesystem scan
- SARIF upload to GitHub Security tab
- Detailed security report generation
- Fails on HIGH/CRITICAL vulnerabilities

## Step 5: Add Build Jobs

Add to `.github/workflows/ci.yml`:

```yaml
  # Job 5: Build Frontend
  build-frontend:
    name: Build Frontend
    runs-on: ubuntu-latest
    needs: [test-frontend, security-scan]
    timeout-minutes: 10
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
      
      - name: Restore npm cache
        uses: actions/cache@v4
        with:
          path: |
            ~/.npm
            node_modules
          key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
      
      - name: Install dependencies
        run: npm ci
      
      - name: Build production bundle
        run: npm run build
        env:
          NODE_ENV: production
      
      - name: Verify build output
        run: |
          if [ ! -d "dist" ]; then
            echo "❌ Build failed: dist directory not found"
            exit 1
          fi
          if [ -z "$(ls -A dist)" ]; then
            echo "❌ Build failed: dist directory is empty"
            exit 1
          fi
          echo "✅ Build successful"
      
      - name: Calculate bundle size
        id: bundle-size
        run: |
          SIZE=$(du -sh dist | cut -f1)
          echo "size=$SIZE" >> $GITHUB_OUTPUT
          echo "📦 Bundle size: $SIZE"
      
      - name: Upload build artifact
        uses: actions/upload-artifact@v4
        with:
          name: frontend-build
          path: dist/
          retention-days: 7
      
      - name: Comment PR with bundle size
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const size = '${{ steps.bundle-size.outputs.size }}';
            const comment = `## 📦 Frontend Build
            
            ✅ Build successful
            📊 Bundle size: **${size}**`;
            
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: comment
            });

  # Job 6: Build Backend Docker
  build-backend:
    name: Build Backend Docker
    runs-on: ubuntu-latest
    needs: [test-backend, security-scan]
    timeout-minutes: 15
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup Docker Buildx
        uses: docker/setup-buildx-action@v3
      
      - name: Build Docker image
        uses: docker/build-push-action@v5
        with:
          context: ./server
          file: ./server/Dockerfile
          push: false
          tags: backend:test
          cache-from: type=gha
          cache-to: type=gha,mode=max
          load: true
      
      - name: Run Trivy image scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'backend:test'
          format: 'sarif'
          output: 'trivy-image-results.sarif'
          severity: 'HIGH,CRITICAL'
          exit-code: '1'
      
      - name: Upload Trivy image results
        if: always()
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-image-results.sarif'
      
      - name: Test Docker image
        run: |
          echo "🧪 Testing Docker image..."
          # Start container
          docker run -d --name test-backend -p 3000:3000 \
            -e NODE_ENV=test \
            -e JWT_SECRET=test-secret \
            backend:test
          
          # Wait for container to start
          sleep 10
          
          # Check if container is running
          if ! docker ps | grep test-backend; then
            echo "❌ Container failed to start"
            docker logs test-backend
            exit 1
          fi
          
          # Test health endpoint (if you have one)
          # curl -f http://localhost:3000/health || exit 1
          
          echo "✅ Docker image test passed"
          
          # Cleanup
          docker stop test-backend
          docker rm test-backend
      
      - name: Calculate image size
        id: image-size
        run: |
          SIZE=$(docker images backend:test --format "{{.Size}}")
          SIZE_MB=$(docker images backend:test --format "{{.Size}}" | sed 's/MB//')
          echo "size=$SIZE" >> $GITHUB_OUTPUT
          echo "size_mb=$SIZE_MB" >> $GITHUB_OUTPUT
          echo "📦 Image size: $SIZE"
          
          # Fail if image is too large
          if (( $(echo "$SIZE_MB > 250" | bc -l) )); then
            echo "❌ Image size exceeds 250MB threshold"
            exit 1
          fi
      
      - name: Upload image scan results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: backend-image-scan
          path: trivy-image-results.sarif
          retention-days: 30
```

**Key Features**:
- Docker Buildx for efficient builds
- Layer caching with GitHub Actions cache
- Trivy image scanning
- Image size validation (< 250MB)
- Container health test
- PR comments with build info

## Step 6: Add Workflow Summary Job

Add to `.github/workflows/ci.yml`:

```yaml
  # Job 7: Workflow Summary
  summary:
    name: CI Summary
    runs-on: ubuntu-latest
    needs: [lint-and-format, test-frontend, test-backend, security-scan, build-frontend, build-backend]
    if: always()
    
    steps:
      - name: Generate summary
        run: |
          echo "# 🎯 CI Workflow Summary" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "## Job Status" >> $GITHUB_STEP_SUMMARY
          echo "| Job | Status |" >> $GITHUB_STEP_SUMMARY
          echo "|-----|--------|" >> $GITHUB_STEP_SUMMARY
          echo "| Lint & Format | ${{ needs.lint-and-format.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Frontend Tests | ${{ needs.test-frontend.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Backend Tests | ${{ needs.test-backend.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Security Scan | ${{ needs.security-scan.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Build Frontend | ${{ needs.build-frontend.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Build Backend | ${{ needs.build-backend.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "## Artifacts" >> $GITHUB_STEP_SUMMARY
          echo "- Frontend test results" >> $GITHUB_STEP_SUMMARY
          echo "- Backend test results" >> $GITHUB_STEP_SUMMARY
          echo "- Security scan report" >> $GITHUB_STEP_SUMMARY
          echo "- Frontend build" >> $GITHUB_STEP_SUMMARY
```

## Step 7: Test the CI Workflow

1. **Create a feature branch**:
```bash
git checkout -b feature/test-ci-workflow
```

2. **Make a small change**:
```bash
echo "# Test CI" >> README.md
git add README.md
git commit -m "test: trigger CI workflow"
git push origin feature/test-ci-workflow
```

3. **Check GitHub Actions**:
- Go to your repository on GitHub
- Click "Actions" tab
- You should see the CI workflow running

4. **Monitor the workflow**:
- Click on the workflow run
- Watch each job execute
- Check for any failures

5. **Create a Pull Request**:
- Create PR from feature branch to develop
- CI should run automatically
- Check for PR comments with coverage and build info

## Troubleshooting

### Issue: npm ci fails

**Solution**:
```bash
# Delete package-lock.json and regenerate
rm package-lock.json
npm install
git add package-lock.json
git commit -m "fix: regenerate package-lock.json"
```

### Issue: Tests fail in CI but pass locally

**Solution**:
- Check Node.js version matches (18)
- Verify environment variables
- Check MySQL connection in backend tests

### Issue: Docker build fails

**Solution**:
```bash
# Test build locally
cd server
docker build -t test:latest .

# Check for errors
docker build -t test:latest --progress=plain .
```

### Issue: Coverage below threshold

**Solution**:
- Write more tests
- Or temporarily lower threshold in vitest.config.js

## Best Practices

1. **Keep jobs fast**: Target < 10 minutes total
2. **Use caching**: npm and Docker layer caching
3. **Fail fast**: Run quick checks first (lint)
4. **Parallel execution**: Run independent jobs in parallel
5. **Clear error messages**: Help developers debug failures
6. **PR comments**: Provide feedback directly in PRs

## Next Steps

✅ CI workflow complete!

Proceed to: [CD Staging Workflow](./04-CD-STAGING.md)
