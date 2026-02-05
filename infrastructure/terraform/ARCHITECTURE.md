# 🏗️ Infrastructure Architecture

## Overview

This document provides a detailed view of the Singha Loyalty System infrastructure architecture deployed on AWS.

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                        │
└────────────────────────────────┬────────────────────────────────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    │                         │
                    │   Route 53 (Optional)   │
                    │   DNS Management        │
                    │                         │
                    └────────────┬────────────┘
                                 │
                    ┌────────────┴────────────┐
                    │                         │
                    │   CloudFront CDN        │
                    │   Global Distribution   │
                    │   - Caching             │
                    │   - SSL/TLS             │
                    │   - DDoS Protection     │
                    │                         │
                    └────────┬────────┬───────┘
                             │        │
                    Frontend │        │ API
                             │        │
                    ┌────────▼────┐   │
                    │             │   │
                    │  S3 Bucket  │   │
                    │  (Static)   │   │
                    │  - React    │   │
                    │  - Assets   │   │
                    │             │   │
                    └─────────────┘   │
                                      │
                         ┌────────────▼────────────┐
                         │                         │
                         │  Application Load       │
                         │  Balancer (ALB)         │
                         │  - Health Checks        │
                         │  - SSL Termination      │
                         │  - Path Routing         │
                         │                         │
                         └────────┬────────────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    │                           │
         ┌──────────▼──────────┐    ┌──────────▼──────────┐
         │                     │    │                     │
         │  ECS Fargate Task   │    │  ECS Fargate Task   │
         │  - Node.js/Express  │    │  - Node.js/Express  │
         │  - Auto-scaling     │    │  - Auto-scaling     │
         │  - Spot Instances   │    │  - Spot Instances   │
         │                     │    │                     │
         └──────────┬──────────┘    └──────────┬──────────┘
                    │                           │
                    └─────────────┬─────────────┘
                                  │
                         ┌────────▼────────────┐
                         │                     │
                         │  RDS MySQL          │
                         │  - Multi-AZ         │
                         │  - Encrypted        │
                         │  - Auto Backups     │
                         │  - Private Subnet   │
                         │                     │
                         └─────────────────────┘
```

---

## Network Architecture

### VPC Layout

```
VPC: 10.0.0.0/16
│
├── Availability Zone 1 (us-east-1a)
│   ├── Public Subnet 1: 10.0.1.0/24
│   │   ├── ALB (Primary)
│   │   └── ECS Tasks (with public IP)
│   │
│   └── Private Subnet 1: 10.0.11.0/24
│       └── RDS Primary Instance
│
└── Availability Zone 2 (us-east-1b)
    ├── Public Subnet 2: 10.0.2.0/24
    │   ├── ALB (Secondary)
    │   └── ECS Tasks (with public IP)
    │
    └── Private Subnet 2: 10.0.12.0/24
        └── RDS Standby Instance (if Multi-AZ)
```

### Network Flow

```
Internet → CloudFront → ALB → ECS Tasks → RDS
                ↓
            S3 Bucket
```

---

## Security Architecture

### Security Layers

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: Edge Security                                       │
│ - CloudFront (DDoS protection)                              │
│ - WAF (Optional)                                            │
│ - SSL/TLS Encryption                                        │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: Network Security                                    │
│ - VPC Isolation                                             │
│ - Security Groups (Stateful Firewall)                       │
│ - Network ACLs (Optional)                                   │
│ - VPC Flow Logs                                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 3: Application Security                                │
│ - IAM Roles (Least Privilege)                               │
│ - Secrets Manager                                           │
│ - Container Image Scanning                                  │
│ - Application-level Authentication                          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 4: Data Security                                       │
│ - RDS Encryption at Rest (KMS)                              │
│ - S3 Encryption (AES-256)                                   │
│ - Encryption in Transit (TLS)                               │
│ - Automated Backups                                         │
└─────────────────────────────────────────────────────────────┘
```

### Security Groups

```
┌─────────────────────────────────────────────────────────────┐
│ ALB Security Group                                           │
│ Inbound:                                                     │
│   - Port 80 (HTTP) from 0.0.0.0/0                          │
│   - Port 443 (HTTPS) from 0.0.0.0/0                        │
│ Outbound:                                                    │
│   - All traffic                                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ ECS Security Group                                           │
│ Inbound:                                                     │
│   - Port 3000 from ALB Security Group                       │
│ Outbound:                                                    │
│   - All traffic (for RDS, ECR, internet)                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ RDS Security Group                                           │
│ Inbound:                                                     │
│   - Port 3306 from ECS Security Group                       │
│ Outbound:                                                    │
│   - All traffic                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Data Flow

### User Request Flow

```
1. User → CloudFront
   ├─ Static Content (HTML/CSS/JS)
   │  └─ CloudFront → S3 → User
   │
   └─ API Request (/api/*)
      └─ CloudFront → ALB → ECS Task → RDS
         └─ Response: RDS → ECS Task → ALB → CloudFront → User
```

### Deployment Flow

```
1. Developer pushes code to Git
   ↓
2. CI/CD builds Docker image
   ↓
3. Image pushed to ECR
   ↓
4. ECS pulls new image
   ↓
5. ECS starts new tasks
   ↓
6. ALB health check passes
   ↓
7. Old tasks drained and stopped
   ↓
8. Deployment complete
```

---

## Component Details

### 1. CloudFront Distribution

**Purpose**: Global content delivery and API gateway

**Configuration**:
- Origins:
  - S3 (frontend static files)
  - ALB (backend API)
- Behaviors:
  - Default: S3 origin (frontend)
  - /api/*: ALB origin (backend)
- Caching:
  - Frontend: 1 hour default TTL
  - API: No caching (TTL = 0)
- Security:
  - HTTPS redirect enabled
  - Origin Access Identity for S3

**Benefits**:
- Low latency globally
- DDoS protection
- SSL/TLS termination
- Cost-effective bandwidth

---

### 2. Application Load Balancer

**Purpose**: Distribute traffic across ECS tasks

**Configuration**:
- Type: Application (Layer 7)
- Scheme: Internet-facing
- Subnets: Public subnets in 2 AZs
- Target Group:
  - Protocol: HTTP
  - Port: 3000
  - Health Check: /health endpoint

**Features**:
- Path-based routing
- Health checks
- Connection draining
- Cross-zone load balancing

---

### 3. ECS Fargate Cluster

**Purpose**: Run containerized application

**Configuration**:
- Launch Type: Fargate (serverless)
- Capacity Providers:
  - FARGATE_SPOT (80% weight)
  - FARGATE (20% weight)
- Task Definition:
  - CPU: 256 (0.25 vCPU)
  - Memory: 512 MB
  - Container: Node.js/Express

**Auto Scaling**:
- Target Tracking:
  - CPU: 70%
  - Memory: 80%
- Min Tasks: 2
- Max Tasks: 10

**Benefits**:
- No server management
- Automatic scaling
- Cost optimization with Spot
- Built-in monitoring

---

### 4. RDS MySQL

**Purpose**: Relational database for application data

**Configuration**:
- Engine: MySQL 8.0.39
- Instance: db.t3.micro (configurable)
- Storage: 20 GB gp3
- Multi-AZ: Optional (recommended for production)
- Encryption: KMS

**Backup**:
- Automated backups: 7 days retention
- Backup window: 03:00-04:00 UTC
- Maintenance window: Sunday 04:00-05:00 UTC

**Monitoring**:
- Enhanced monitoring (60s interval)
- CloudWatch logs (error, slow query)
- Performance Insights (production)

---

### 5. ECR Repository

**Purpose**: Store Docker images

**Configuration**:
- Image scanning: Enabled
- Encryption: AES-256
- Lifecycle policy:
  - Keep last 10 tagged images
  - Remove untagged after 7 days

---

### 6. S3 + CloudFront

**Purpose**: Host and deliver frontend

**S3 Configuration**:
- Versioning: Enabled
- Encryption: AES-256
- Public access: Blocked
- Website hosting: Enabled

**CloudFront Configuration**:
- Origin: S3 bucket
- OAI: Enabled
- HTTPS: Required
- Caching: Optimized for static content

---

## Monitoring & Logging

### CloudWatch Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      CloudWatch                              │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Metrics    │  │     Logs     │  │    Alarms    │     │
│  │              │  │              │  │              │     │
│  │ - ECS CPU    │  │ - ECS Logs   │  │ - CPU > 80%  │     │
│  │ - ECS Memory │  │ - VPC Flow   │  │ - Memory>80% │     │
│  │ - RDS CPU    │  │ - RDS Logs   │  │ - Unhealthy  │     │
│  │ - ALB Req    │  │              │  │   Targets    │     │
│  │              │  │              │  │              │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Container Insights                       │  │
│  │  - Task-level metrics                                │  │
│  │  - Container-level metrics                           │  │
│  │  - Performance monitoring                            │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Log Groups

- `/ecs/singha-loyalty` - Application logs
- `/aws/vpc/singha-loyalty-flow-logs` - Network traffic
- `/aws/rds/instance/singha-loyalty-db/error` - Database errors
- `/aws/rds/instance/singha-loyalty-db/slowquery` - Slow queries

---

## Disaster Recovery

### Backup Strategy

```
┌─────────────────────────────────────────────────────────────┐
│ RDS Automated Backups                                        │
│ - Daily snapshots                                           │
│ - 7-day retention                                           │
│ - Point-in-time recovery                                    │
│ - Cross-region replication (optional)                       │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ S3 Versioning                                                │
│ - All object versions retained                              │
│ - 30-day lifecycle for old versions                         │
│ - Cross-region replication (optional)                       │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ ECR Image Retention                                          │
│ - Last 10 tagged images                                     │
│ - Untagged images removed after 7 days                      │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ Terraform State                                              │
│ - Remote state in S3 (optional)                             │
│ - State locking with DynamoDB                               │
│ - Versioning enabled                                        │
└─────────────────────────────────────────────────────────────┘
```

### Recovery Time Objectives

| Component | RTO | RPO | Recovery Method |
|-----------|-----|-----|-----------------|
| ECS Tasks | 5 min | 0 | Auto-scaling, new task deployment |
| RDS | 30 min | 5 min | Automated backup restore |
| S3/CloudFront | 10 min | 0 | Versioning, re-upload |
| Infrastructure | 20 min | 0 | Terraform re-apply |

---

## Scalability

### Horizontal Scaling

```
┌─────────────────────────────────────────────────────────────┐
│ ECS Auto Scaling                                             │
│                                                              │
│  Low Traffic (1-100 req/min)                                │
│  ├─ 2 tasks                                                 │
│  └─ Cost: ~$7/month                                         │
│                                                              │
│  Medium Traffic (100-1000 req/min)                          │
│  ├─ 5 tasks                                                 │
│  └─ Cost: ~$18/month                                        │
│                                                              │
│  High Traffic (1000+ req/min)                               │
│  ├─ 10 tasks                                                │
│  └─ Cost: ~$35/month                                        │
└─────────────────────────────────────────────────────────────┘
```

### Vertical Scaling

```
┌─────────────────────────────────────────────────────────────┐
│ RDS Instance Scaling                                         │
│                                                              │
│  Development: db.t3.micro                                    │
│  ├─ 1 vCPU, 1 GB RAM                                        │
│  └─ Cost: ~$17/month                                        │
│                                                              │
│  Production: db.t3.small                                     │
│  ├─ 2 vCPU, 2 GB RAM                                        │
│  └─ Cost: ~$56/month (Multi-AZ)                             │
│                                                              │
│  High Load: db.t3.medium                                     │
│  ├─ 2 vCPU, 4 GB RAM                                        │
│  └─ Cost: ~$116/month (Multi-AZ)                            │
└─────────────────────────────────────────────────────────────┘
```

---

## Cost Optimization

### Architecture Decisions for Cost

1. **Fargate Spot** (70% savings)
   - 80% of tasks on Spot
   - 20% on On-Demand for stability

2. **Right-Sized Resources**
   - Minimal CPU/Memory for tasks
   - t3.micro RDS for development
   - Auto-scaling to match demand

3. **CloudFront Caching**
   - Reduced origin requests
   - Lower bandwidth costs
   - Faster response times

4. **S3 Lifecycle Policies**
   - Remove old versions
   - Optimize storage costs

5. **Log Retention**
   - 7-day retention (configurable)
   - Reduced storage costs

---

## Well-Architected Framework Alignment

### Operational Excellence
✅ Infrastructure as Code (Terraform)
✅ Automated deployments
✅ Comprehensive monitoring
✅ Centralized logging

### Security
✅ Defense in depth
✅ Encryption at rest and in transit
✅ Least privilege IAM roles
✅ Secrets management
✅ Network isolation

### Reliability
✅ Multi-AZ deployment
✅ Auto-scaling
✅ Health checks
✅ Automated backups
✅ Circuit breaker pattern

### Performance Efficiency
✅ CloudFront CDN
✅ Auto-scaling
✅ Right-sized resources
✅ Container orchestration

### Cost Optimization
✅ Fargate Spot instances
✅ Auto-scaling
✅ Resource tagging
✅ Lifecycle policies
✅ Cost monitoring

### Sustainability
✅ Serverless compute (Fargate)
✅ Auto-scaling (no idle resources)
✅ Efficient resource utilization
✅ Regional deployment

---

## Future Enhancements

### Phase 2
- [ ] Custom domain with Route 53
- [ ] SSL certificate with ACM
- [ ] AWS WAF for additional security
- [ ] ElastiCache for caching
- [ ] Multi-region deployment

### Phase 3
- [ ] Blue/green deployments
- [ ] Canary deployments
- [ ] AWS X-Ray for tracing
- [ ] Advanced monitoring dashboards
- [ ] Automated security scanning

### Phase 4
- [ ] Kubernetes migration (EKS)
- [ ] Service mesh (App Mesh)
- [ ] Advanced analytics
- [ ] Machine learning integration
- [ ] Global acceleration

---

## References

- **AWS Well-Architected Framework**: https://aws.amazon.com/architecture/well-architected/
- **ECS Best Practices**: https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/
- **RDS Best Practices**: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs

---

**Document Version**: 1.0
**Last Updated**: February 2026
**Architecture Review**: Quarterly
