# CI/CD Architecture Diagrams

## 1. Complete Pipeline Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DEVELOPER WORKFLOW                                 │
│                                                                              │
│  Developer → Feature Branch → Code + Tests → Push to GitHub → Create PR     │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          CI WORKFLOW (All Branches)                          │
│                                                                              │
│  ┌──────────────┐                                                           │
│  │ Lint & Format│                                                           │
│  │   (2 min)    │                                                           │
│  └──────┬───────┘                                                           │
│         │                                                                    │
│         ├─────────────┬──────────────┬──────────────┐                      │
│         ▼             ▼              ▼              ▼                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐                  │
│  │ Frontend │  │ Backend  │  │ Security │  │  Build   │                   │
│  │  Tests   │  │  Tests   │  │   Scan   │  │ Frontend │                   │
│  │ (3 min)  │  │ (4 min)  │  │ (3 min)  │  │ (2 min)  │                   │
│  │          │  │ + MySQL  │  │ npm audit│  │          │                   │
│  │ Vitest   │  │ Vitest   │  │ + Trivy  │  │  Vite    │                   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘                  │
│       │             │              │              │                         │
│       └─────────────┴──────────────┴──────────────┘                        │
│                            │                                                │
│                            ▼                                                │
│                     ┌──────────────┐                                       │
│                     │ Build Backend│                                       │
│                     │   Docker     │                                       │
│                     │   (3 min)    │                                       │
│                     │ + Trivy Scan │                                       │
│                     └──────────────┘                                       │
│                                                                              │
│  Total Time: ~8 minutes (with caching and parallel execution)              │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                    ┌─────────────────┴─────────────────┐
                    │                                   │
                    ▼                                   ▼
┌──────────────────────────────────────┐  ┌──────────────────────────────────┐
│   CD STAGING (Develop Branch)        │  │  CD PRODUCTION (Main Branch)     │
│                                      │  │                                  │
│  ┌────────────────────────────────┐ │  │  ┌────────────────────────────┐ │
│  │ 1. Run CI Workflow             │ │  │  │ 1. Run CI Workflow         │ │
│  └────────────────────────────────┘ │  │  └────────────────────────────┘ │
│                │                     │  │                │                 │
│                ▼                     │  │                ▼                 │
│  ┌────────────────────────────────┐ │  │  ┌────────────────────────────┐ │
│  │ 2. Build & Push to ECR         │ │  │  │ 2. Build & Push to ECR     │ │
│  │    Tags: staging-latest        │ │  │  │    Tags: production-latest │ │
│  │          staging-{sha}         │ │  │  │          production-{sha}  │ │
│  │          staging-{run}         │ │  │  │          production-v{ver} │ │
│  └────────────────────────────────┘ │  │  └────────────────────────────┘ │
│                │                     │  │                │                 │
│                ▼                     │  │                ▼                 │
│  ┌────────────────────────────────┐ │  │  ┌────────────────────────────┐ │
│  │ 3. Deploy to ECS Staging       │ │  │  │ 3. ⏸️  MANUAL APPROVAL      │ │
│  │    - Update task definition    │ │  │  │    Required reviewers: 2   │ │
│  │    - Update service            │ │  │  │    Wait for approval...    │ │
│  │    - Wait for stability        │ │  │  └────────────────────────────┘ │
│  └────────────────────────────────┘ │  │                │                 │
│                │                     │  │                ▼                 │
│                ▼                     │  │  ┌────────────────────────────┐ │
│  ┌────────────────────────────────┐ │  │  │ 4. Deploy to ECS Production│ │
│  │ 4. Run Smoke Tests             │ │  │  │    - Update task definition│ │
│  │    - Health check              │ │  │  │    - Update service        │ │
│  │    - API endpoints             │ │  │  │    - Wait for stability    │ │
│  │    - Database connectivity     │ │  │  │    - Extended health checks│ │
│  └────────────────────────────────┘ │  │  └────────────────────────────┘ │
│                │                     │  │                │                 │
│                ▼                     │  │                ▼                 │
│  ┌────────────────────────────────┐ │  │  ┌────────────────────────────┐ │
│  │ 5. Notify Team (Slack)         │ │  │  │ 5. Post-Deploy Validation  │ │
│  │    ✅ Staging deployed          │ │  │  │    - Comprehensive tests   │ │
│  └────────────────────────────────┘ │  │  │    - Monitor error rates   │ │
│                                      │  │  │    - Create GitHub release │ │
│  Auto-rollback on failure ⚠️         │  │  └────────────────────────────┘ │
│                                      │  │                │                 │
└──────────────────────────────────────┘  │                ▼                 │
                                          │  ┌────────────────────────────┐ │
                                          │  │ 6. Notify Team (Slack)     │ │
                                          │  │    ✅ Production deployed   │ │
                                          │  └────────────────────────────┘ │
                                          │                                  │
                                          │  Auto-rollback on failure ⚠️     │
                                          └──────────────────────────────────┘
```

## 2. Security Scanning Layers

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SECURITY SCANNING LAYERS                             │
└─────────────────────────────────────────────────────────────────────────────┘

Layer 1: Source Code Dependencies
┌──────────────────────────────────────┐
│  npm audit (Frontend)                │
│  • Scans package.json dependencies   │
│  • Checks for known vulnerabilities  │
│  • Severity: HIGH, CRITICAL          │
│  • Action: Block deployment          │
└──────────────────────────────────────┘
                │
                ▼
┌──────────────────────────────────────┐
│  npm audit (Backend)                 │
│  • Scans server/package.json         │
│  • Checks for known vulnerabilities  │
│  • Severity: HIGH, CRITICAL          │
│  • Action: Block deployment          │
└──────────────────────────────────────┘
                │
                ▼
Layer 2: Filesystem Scan
┌──────────────────────────────────────┐
│  Trivy Filesystem Scan               │
│  • Scans entire codebase             │
│  • Checks for misconfigurations      │
│  • Detects secrets in code           │
│  • Severity: HIGH, CRITICAL          │
│  • Action: Block deployment          │
└──────────────────────────────────────┘
                │
                ▼
Layer 3: Docker Image Scan
┌──────────────────────────────────────┐
│  Trivy Image Scan (Build)            │
│  • Scans Docker image layers         │
│  • Checks OS packages                │
│  • Checks application dependencies   │
│  • Severity: HIGH, CRITICAL          │
│  • Action: Block deployment          │
└──────────────────────────────────────┘
                │
                ▼
Layer 4: Registry Scan
┌──────────────────────────────────────┐
│  Trivy Image Scan (ECR)              │
│  • Scans pushed image in ECR         │
│  • Final verification before deploy  │
│  • Severity: HIGH, CRITICAL          │
│  • Action: Block deployment          │
└──────────────────────────────────────┘
                │
                ▼
Layer 5: GitHub Security
┌──────────────────────────────────────┐
│  SARIF Upload to GitHub Security     │
│  • Centralized security dashboard    │
│  • Tracks vulnerabilities over time  │
│  • Integrates with Dependabot        │
│  • Action: Alert team                │
└──────────────────────────────────────┘
```

## 3. Caching Strategy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CACHING ARCHITECTURE                               │
└─────────────────────────────────────────────────────────────────────────────┘

NPM Dependencies Cache
┌──────────────────────────────────────┐
│  Cache Key:                          │
│  ${{ runner.os }}-node-${{ hash }}   │
│                                      │
│  Cached Paths:                       │
│  • ~/.npm                            │
│  • node_modules                      │
│  • server/node_modules               │
│                                      │
│  Cache Hit: 30 seconds               │
│  Cache Miss: 3-5 minutes             │
│  Savings: 2.5-4.5 minutes            │
└──────────────────────────────────────┘
                │
                ▼
Docker Layer Cache
┌──────────────────────────────────────┐
│  Cache Type: GitHub Actions Cache    │
│  (type=gha, mode=max)                │
│                                      │
│  Cached Layers:                      │
│  • Base image (node:18-alpine)       │
│  • npm install layer                 │
│  • Application code layer            │
│                                      │
│  Cache Hit: 1-2 minutes              │
│  Cache Miss: 5-8 minutes             │
│  Savings: 3-6 minutes                │
└──────────────────────────────────────┘
                │
                ▼
Build Artifact Cache
┌──────────────────────────────────────┐
│  Cache Key: build-${{ github.sha }}  │
│                                      │
│  Cached Artifacts:                   │
│  • dist/ (frontend build)            │
│  • Coverage reports                  │
│  • Test results                      │
│                                      │
│  Reused across jobs                  │
│  Savings: 2-3 minutes                │
└──────────────────────────────────────┘

Total Time Savings: 7-13 minutes per run
Pipeline Time: 15-20 min → 5-8 min (60% faster)
```

## 4. Deployment Flow with Rollback

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        DEPLOYMENT WITH ROLLBACK                              │
└─────────────────────────────────────────────────────────────────────────────┘

Current State
┌──────────────────────────────────────┐
│  ECS Service                         │
│  Task Definition: v10                │
│  Desired Count: 2                    │
│  Running Tasks: 2                    │
│  Status: STABLE ✅                    │
└──────────────────────────────────────┘
                │
                ▼
Deployment Initiated
┌──────────────────────────────────────┐
│  1. Register new task definition     │
│     Task Definition: v11             │
│     Image: backend:production-abc123 │
└──────────────────────────────────────┘
                │
                ▼
┌──────────────────────────────────────┐
│  2. Update ECS service               │
│     New Task Definition: v11         │
│     Deployment Type: Rolling         │
└──────────────────────────────────────┘
                │
                ▼
Rolling Update
┌──────────────────────────────────────┐
│  ECS Service                         │
│  Old Tasks (v10): 2 → 1 → 0          │
│  New Tasks (v11): 0 → 1 → 2          │
│  Status: IN_PROGRESS 🔄               │
└──────────────────────────────────────┘
                │
                ├─────────────────┐
                │                 │
                ▼                 ▼
        Success Path      Failure Path
┌──────────────────────┐  ┌──────────────────────┐
│  3. Health checks    │  │  3. Health checks    │
│     ✅ All pass       │  │     ❌ Failed         │
└──────────────────────┘  └──────────────────────┘
                │                 │
                ▼                 ▼
┌──────────────────────┐  ┌──────────────────────┐
│  4. Wait for         │  │  4. Detect failure   │
│     stability        │  │     - Health check   │
│     (10-15 min)      │  │     - Error rate     │
└──────────────────────┘  │     - Timeout        │
                │         └──────────────────────┘
                ▼                 │
┌──────────────────────┐          ▼
│  5. Smoke tests      │  ┌──────────────────────┐
│     ✅ All pass       │  │  5. AUTOMATIC        │
└──────────────────────┘  │     ROLLBACK         │
                │         │     - Revert to v10  │
                ▼         │     - Force deploy   │
┌──────────────────────┐  └──────────────────────┘
│  6. Deployment       │          │
│     SUCCESSFUL ✅     │          ▼
│     Task Def: v11    │  ┌──────────────────────┐
│     Running: 2       │  │  6. Notify team      │
└──────────────────────┘  │     🚨 Rollback done  │
                │         │     - Slack alert    │
                ▼         │     - GitHub comment │
┌──────────────────────┐  └──────────────────────┘
│  7. Notify team      │          │
│     ✅ Deployed       │          ▼
│     - Slack message  │  ┌──────────────────────┐
│     - GitHub release │  │  Service restored    │
└──────────────────────┘  │  to previous state   │
                          │  MTTR: < 5 minutes   │
                          └──────────────────────┘
```

## 5. Branch Strategy and Environments

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         BRANCH STRATEGY & ENVIRONMENTS                       │
└─────────────────────────────────────────────────────────────────────────────┘

Git Branches                    GitHub Actions                  AWS Environments
─────────────────────────────────────────────────────────────────────────────

feature/my-feature
    │
    │ Push
    ▼
┌─────────────┐                ┌─────────────┐
│  Feature    │───────────────▶│  CI Only    │
│  Branch     │                │  No Deploy  │
└─────────────┘                └─────────────┘
    │
    │ PR + Merge
    ▼
┌─────────────┐                ┌─────────────┐                ┌─────────────┐
│  develop    │───────────────▶│ CI + CD     │───────────────▶│  Staging    │
│  Branch     │                │ Staging     │                │  Environment│
└─────────────┘                └─────────────┘                │             │
    │                                                          │ • Auto      │
    │ PR + Merge                                               │   deploy    │
    ▼                                                          │ • No        │
┌─────────────┐                ┌─────────────┐                │   approval  │
│    main     │───────────────▶│ CI + CD     │───┐            └─────────────┘
│   Branch    │                │ Production  │   │
└─────────────┘                └─────────────┘   │
                                                  │ Manual
                                                  │ Approval
                                                  ▼
                                          ┌─────────────┐
                                          │ Production  │
                                          │ Environment │
                                          │             │
                                          │ • Manual    │
                                          │   approval  │
                                          │ • 2         │
                                          │   reviewers │
                                          └─────────────┘

Environment Configuration:
─────────────────────────────────────────────────────────────────────────────

Staging:
• DATABASE_URL: staging-db.amazonaws.com
• JWT_SECRET: staging-secret-xyz
• API_BASE_URL: https://staging-api.example.com
• Auto-deploy on develop push
• No approval required

Production:
• DATABASE_URL: production-db.amazonaws.com
• JWT_SECRET: production-secret-abc
• API_BASE_URL: https://api.example.com
• Manual approval required (2 reviewers)
• Wait timer: 0 minutes (can be increased)
```

## 6. Monitoring and Alerting Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      MONITORING & ALERTING ARCHITECTURE                      │
└─────────────────────────────────────────────────────────────────────────────┘

Pipeline Execution
        │
        ▼
┌──────────────────────────────────────┐
│  GitHub Actions Workflow             │
│  • Collects metrics                  │
│  • Tracks duration                   │
│  • Records status                    │
└──────────────────────────────────────┘
        │
        ├─────────────────┬─────────────────┬─────────────────┐
        ▼                 ▼                 ▼                 ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  GitHub     │  │   Slack     │  │  GitHub     │  │  CloudWatch │
│  Deployments│  │ Notifications│  │  Security   │  │    Logs     │
│     API     │  │             │  │     Tab     │  │             │
└─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘
        │                 │                 │                 │
        ▼                 ▼                 ▼                 ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│ Deployment  │  │ Team gets   │  │ Security    │  │ Application │
│ history     │  │ real-time   │  │ dashboard   │  │ logs for    │
│ tracking    │  │ updates     │  │ with        │  │ debugging   │
│             │  │             │  │ vulns       │  │             │
└─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘

Notification Types:
─────────────────────────────────────────────────────────────────────────────

✅ Success Notifications:
• Deployment completed successfully
• All tests passed
• Security scans clean
• Sent to: #deployments channel

⚠️ Warning Notifications:
• Medium severity vulnerabilities found
• Test coverage below target
• Build time increased significantly
• Sent to: #deployments channel

🚨 Critical Notifications:
• Deployment failed
• Critical vulnerabilities found
• Production rollback triggered
• Tests failed
• Sent to: #alerts channel + @on-call

📊 Metrics Tracked:
• Build duration per job
• Test execution time
• Deployment frequency
• Success/failure rate
• Coverage percentage
• Security vulnerabilities count
```

---

## Legend

```
Symbols Used:
─────────────────────────────────────────────────────────────────────────────
│  ▼  ▶  ◀  ▲     Flow direction
┌─┐ └─┘          Box borders
✅               Success/Completed
❌               Failure/Error
⚠️                Warning
🚨               Critical Alert
🔄               In Progress
⏸️                Paused/Waiting
📊               Metrics/Data
```

---

**Note**: These diagrams are text-based for easy viewing in any text editor. For presentation purposes, consider creating visual diagrams using tools like:
- Lucidchart
- Draw.io
- Mermaid (can be embedded in Markdown)
- PlantUML
