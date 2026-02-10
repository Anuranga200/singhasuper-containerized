# GitHub Actions CI/CD Pipeline Documentation

## 📚 Complete Guide Index

This directory contains comprehensive documentation for implementing a production-grade GitHub Actions CI/CD pipeline with testing, security scanning, and AWS ECR/ECS deployment.

### 🎯 Quick Start

**New to CI/CD?** Start here:
1. Read [GITHUB_ACTIONS_COMPLETE_GUIDE.md](./GITHUB_ACTIONS_COMPLETE_GUIDE.md) - Overview and philosophy
2. Follow [01-AWS-SETUP.md](./01-AWS-SETUP.md) - AWS infrastructure setup
3. Follow [02-BACKEND-TESTING.md](./02-BACKEND-TESTING.md) - Testing infrastructure
4. Implement workflows from `.kiro/specs/github-actions-cicd-pipeline/`

**Experienced DevOps Engineer?** Jump to:
- [Implementation Tasks](../.kiro/specs/github-actions-cicd-pipeline/tasks.md) - Detailed task checklist
- [Design Document](../.kiro/specs/github-actions-cicd-pipeline/design.md) - Architecture and decisions

### 📖 Documentation Structure

```
docs/cicd/
├── README.md (this file)                          # Documentation index
├── GITHUB_ACTIONS_COMPLETE_GUIDE.md               # Main guide with philosophy
├── 01-AWS-SETUP.md                                # AWS IAM, ECR, ECS setup
├── 02-BACKEND-TESTING.md                          # Vitest setup and test writing
└── (more guides to be created)

.kiro/specs/github-actions-cicd-pipeline/
├── requirements.md                                # User stories and requirements
├── design.md                                      # Architecture and design decisions
└── tasks.md                                       # Implementation task checklist
```

### 🎓 Learning Path

#### Phase 1: Foundation (Week 1)
**Goal**: Understand CI/CD concepts and setup AWS infrastructure

**Read**:
- [GITHUB_ACTIONS_COMPLETE_GUIDE.md](./GITHUB_ACTIONS_COMPLETE_GUIDE.md) - Sections 1-2
- [requirements.md](../.kiro/specs/github-actions-cicd-pipeline/requirements.md) - All sections

**Do**:
- [01-AWS-SETUP.md](./01-AWS-SETUP.md) - Complete AWS setup
- Configure GitHub repository settings
- Setup GitHub secrets

**Time**: 3-4 hours

#### Phase 2: Testing Infrastructure (Week 1-2)
**Goal**: Setup comprehensive backend testing

**Read**:
- [02-BACKEND-TESTING.md](./02-BACKEND-TESTING.md) - All sections
- [design.md](../.kiro/specs/github-actions-cicd-pipeline/design.md) - Section 6 (Testing Strategy)

**Do**:
- Install Vitest and dependencies
- Write unit tests for controllers
- Write integration tests for APIs
- Achieve 60% coverage

**Time**: 4-6 hours

#### Phase 3: CI Workflow (Week 2)
**Goal**: Implement continuous integration pipeline

**Read**:
- [design.md](../.kiro/specs/github-actions-cicd-pipeline/design.md) - Section 2.1 (CI Workflow)

**Do**:
- Create `.github/workflows/ci.yml`
- Implement lint, test, security scan jobs
- Test CI workflow with feature branch

**Time**: 3-4 hours

#### Phase 4: CD Workflows (Week 3)
**Goal**: Implement continuous deployment to staging and production

**Read**:
- [design.md](../.kiro/specs/github-actions-cicd-pipeline/design.md) - Sections 2.2-2.3

**Do**:
- Create staging deployment workflow
- Create production deployment workflow
- Test deployments end-to-end

**Time**: 4-5 hours

#### Phase 5: Optimization & Monitoring (Week 4)
**Goal**: Optimize performance and setup monitoring

**Read**:
- [design.md](../.kiro/specs/github-actions-cicd-pipeline/design.md) - Sections 5, 7, 9

**Do**:
- Implement caching strategies
- Setup Slack notifications
- Optimize Docker builds
- Document runbooks

**Time**: 3-4 hours

**Total Time**: 18-26 hours over 3-4 weeks

### 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Developer Workflow                        │
│                                                              │
│  1. Create feature branch                                   │
│  2. Write code + tests                                      │
│  3. Push to GitHub                                          │
│  4. CI runs automatically                                   │
│  5. Create PR                                               │
│  6. Code review + CI checks                                 │
│  7. Merge to develop → Deploy to staging                    │
│  8. Merge to main → Deploy to production (with approval)    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Actions Pipeline                   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  CI Workflow (All Branches)                          │  │
│  │  • Lint & Format Check                               │  │
│  │  • Frontend Tests (Vitest)                           │  │
│  │  • Backend Tests (Vitest + MySQL)                    │  │
│  │  • Security Scan (npm audit + Trivy)                 │  │
│  │  • Build Frontend (Vite)                             │  │
│  │  • Build Backend (Docker)                            │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  CD Staging (Develop Branch)                         │  │
│  │  • Run CI Workflow                                   │  │
│  │  • Push Docker Image to ECR (staging tags)           │  │
│  │  • Deploy to ECS Staging                             │  │
│  │  • Run Smoke Tests                                   │  │
│  │  • Notify Team                                       │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  CD Production (Main Branch)                         │  │
│  │  • Run CI Workflow                                   │  │
│  │  • Push Docker Image to ECR (production tags)        │  │
│  │  • ⏸️  Manual Approval Gate                          │  │
│  │  • Deploy to ECS Production                          │  │
│  │  • Run Comprehensive Validation                      │  │
│  │  • Create GitHub Release                             │  │
│  │  • Notify Team                                       │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                         AWS Infrastructure                   │
│                                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │   ECR    │  │   ECS    │  │   ECS    │  │   RDS    │   │
│  │ Registry │  │ Staging  │  │Production│  │ Database │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 🔑 Key Features

#### ✅ Comprehensive Testing
- **Frontend**: Vitest + React Testing Library
- **Backend**: Vitest + Supertest + MySQL service
- **Coverage**: 70% frontend, 60% backend minimum
- **Integration**: Real database tests in CI

#### 🔒 Security Scanning
- **Dependency Scanning**: npm audit (HIGH/CRITICAL)
- **Image Scanning**: Trivy (OS + dependencies)
- **SAST**: CodeQL (optional)
- **Secrets**: GitHub Secrets + AWS Secrets Manager

#### 🚀 Deployment Strategy
- **Staging**: Auto-deploy on develop branch
- **Production**: Manual approval required
- **Rollback**: Automated on health check failure
- **Zero-Downtime**: ECS rolling updates

#### ⚡ Performance Optimization
- **Caching**: npm dependencies + Docker layers
- **Parallel Jobs**: Tests run in parallel
- **Conditional Execution**: Skip unnecessary jobs
- **Build Time**: < 10 minutes total

#### 📊 Monitoring & Observability
- **Metrics**: Build time, test coverage, deployment frequency
- **Notifications**: Slack/Teams integration
- **Deployment Tracking**: GitHub Deployments API
- **Logs**: 90-day retention

### 📋 Prerequisites Checklist

Before starting, ensure you have:

- [ ] GitHub repository with admin access
- [ ] AWS account with ECR and ECS setup
- [ ] Node.js 18+ installed locally
- [ ] Docker installed locally
- [ ] AWS CLI configured
- [ ] Basic understanding of:
  - [ ] Git workflows
  - [ ] Docker containers
  - [ ] AWS services (ECR, ECS, IAM)
  - [ ] YAML syntax
  - [ ] Testing concepts

### 🎯 Success Metrics

After implementation, you should achieve:

| Metric | Before CI/CD | After CI/CD | Target |
|--------|--------------|-------------|--------|
| Deployment Frequency | Weekly | Multiple/day | ✅ 10x improvement |
| Lead Time for Changes | Days | < 1 hour | ✅ 24x improvement |
| Change Failure Rate | 20-30% | < 5% | ✅ 4-6x improvement |
| MTTR | Hours | < 30 min | ✅ 4x improvement |
| Test Coverage | 0% | 60-70% | ✅ New capability |
| Security Scans | Manual | Automated | ✅ New capability |

### 🆘 Getting Help

#### Common Issues

1. **AWS Authentication Fails**
   - Check IAM permissions
   - Verify GitHub secrets are correct
   - See [01-AWS-SETUP.md](./01-AWS-SETUP.md) troubleshooting section

2. **Tests Fail in CI but Pass Locally**
   - Check environment variables
   - Verify MySQL service is running
   - See [02-BACKEND-TESTING.md](./02-BACKEND-TESTING.md) troubleshooting section

3. **Docker Build Fails**
   - Check Dockerfile syntax
   - Verify base image is accessible
   - Check build context

4. **ECS Deployment Hangs**
   - Check ECS service events
   - Verify task definition is valid
   - Check security groups and networking

#### Resources

- **GitHub Actions Docs**: https://docs.github.com/en/actions
- **Vitest Docs**: https://vitest.dev/
- **AWS ECR Docs**: https://docs.aws.amazon.com/ecr/
- **AWS ECS Docs**: https://docs.aws.amazon.com/ecs/
- **Trivy Docs**: https://aquasecurity.github.io/trivy/

#### Support Channels

- **Internal**: Create issue in this repository
- **GitHub Actions**: GitHub Community Forum
- **AWS**: AWS Support (if you have support plan)

### 🔄 Maintenance

#### Regular Tasks

**Weekly**:
- [ ] Review failed pipeline runs
- [ ] Check security scan results
- [ ] Monitor GitHub Actions usage

**Monthly**:
- [ ] Review and update dependencies
- [ ] Analyze pipeline metrics
- [ ] Optimize slow jobs

**Quarterly**:
- [ ] Rotate AWS credentials
- [ ] Review IAM policies
- [ ] Update documentation
- [ ] Team training/knowledge sharing

**Annually**:
- [ ] Major version updates
- [ ] Architecture review
- [ ] Disaster recovery test

### 📝 Contributing

When updating this documentation:

1. Keep guides practical and example-driven
2. Include "Why?" explanations for decisions
3. Add troubleshooting sections
4. Update this README index
5. Test all commands before documenting

### 📄 License

This documentation is part of the Singha Loyalty System project.

---

**Last Updated**: February 2026
**Maintained By**: DevOps Team
**Version**: 1.0.0
