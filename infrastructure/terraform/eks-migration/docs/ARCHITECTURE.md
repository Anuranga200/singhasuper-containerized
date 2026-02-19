# Architecture Documentation

## Overview

This document provides detailed architecture diagrams and explanations for the EKS migration solution. The architecture is designed to enable temporary exploration of EKS while maintaining the existing ECS deployment as a fallback.

---

## Table of Contents

1. [High-Level Architecture](#high-level-architecture)
2. [Network Architecture](#network-architecture)
3. [Traffic Routing Architecture](#traffic-routing-architecture)
4. [Security Architecture](#security-architecture)
5. [Monitoring Architecture](#monitoring-architecture)
6. [Architecture States](#architecture-states)
7. [Design Principles](#design-principles)

---

## High-Level Architecture

### Current State (ECS Only)

```
┌─────────────────────────────────────────────────────────┐
│                      Internet                            │
└────────────────────┬────────────────────────────────────┘
                     │
                ┌────▼────┐
                │   ALB   │
                └────┬────┘
                     │
                ┌────▼────────┐
                │ ECS Target  │
                │   Group     │
                │ Weight: 100%│
                └────┬────────┘
                     │
            ┌────────▼────────┐
            │  ECS Fargate    │
            │     Tasks       │
            │   (2 tasks)     │
            └────────┬────────┘
                     │
                ┌────▼────┐
                │   RDS   │
                │PostgreSQL│
                └─────────┘
```

### Target State (ECS + EKS Parallel)

```
┌──────────────────────────────────────────────────────────────┐
│                         Internet                              │
└────────────────────────┬─────────────────────────────────────┘
                         │
                    ┌────▼────┐
                    │   ALB   │
                    │ (Shared)│
                    └────┬────┘
                         │
          ┌──────────────┴──────────────┐
          │                             │
     ┌────▼────────┐              ┌────▼────────┐
     │ ECS Target  │              │ EKS Target  │
     │   Group     │              │   Group     │
     │Weight: 100% │              │ Weight: 0%  │
     │    ↓ 0%     │              │    ↑ 100%   │
     └────┬────────┘              └────┬────────┘
          │                             │
     ┌────▼────────┐              ┌────▼────────┐
     │  Fargate    │              │ EKS Cluster │
     │   Tasks     │              │             │
     │  (2 tasks)  │              │  ┌────────┐ │
     └────┬────────┘              │  │ Nodes  │ │
          │                       │  │(2 nodes)│ │
          │                       │  └───┬────┘ │
          │                       │      │      │
          │                       │  ┌───▼────┐ │
          │                       │  │  Pods  │ │
          │                       │  │(2 pods)│ │
          │                       │  └───┬────┘ │
          │                       └──────┼──────┘
          │                              │
          └──────────────┬───────────────┘
                         │
                    ┌────▼────┐
                    │   RDS   │
                    │PostgreSQL│
                    │ (Shared) │
                    └─────────┘
                         ▲
                         │
                    ┌────┴────┐
                    │   ECR   │
                    │ (Shared)│
                    └─────────┘
```

**Key Components:**
- **ALB**: Shared load balancer with weighted routing
- **ECS**: Existing Fargate deployment (unchanged)
- **EKS**: New Kubernetes cluster (temporary)
- **RDS**: Shared PostgreSQL database
- **ECR**: Shared container registry

---

## Network Architecture

### VPC Layout

```
┌─────────────────────────────────────────────────────────────────┐
│                          VPC (10.0.0.0/16)                       │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    Public Subnets                           │ │
│  │  ┌──────────────────┐         ┌──────────────────┐        │ │
│  │  │  AZ-1 Public     │         │  AZ-2 Public     │        │ │
│  │  │  10.0.1.0/24     │         │  10.0.2.0/24     │        │ │
│  │  │                  │         │                  │        │ │
│  │  │  ┌────┐          │         │          ┌────┐ │        │ │
│  │  │  │ALB │          │         │          │ALB │ │        │ │
│  │  │  └────┘          │         │          └────┘ │        │ │
│  │  │  ┌────┐          │         │          ┌────┐ │        │ │
│  │  │  │NAT │          │         │          │NAT │ │        │ │
│  │  │  └────┘          │         │          └────┘ │        │ │
│  │  └──────────────────┘         └──────────────────┘        │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                   Private Subnets                           │ │
│  │  ┌──────────────────┐         ┌──────────────────┐        │ │
│  │  │  AZ-1 Private    │         │  AZ-2 Private    │        │ │
│  │  │  10.0.11.0/24    │         │  10.0.12.0/24    │        │ │
│  │  │                  │         │                  │        │ │
│  │  │  ┌────────┐      │         │      ┌────────┐ │        │ │
│  │  │  │ECS Task│      │         │      │ECS Task│ │        │ │
│  │  │  └────────┘      │         │      └────────┘ │        │ │
│  │  │  ┌────────┐      │         │      ┌────────┐ │        │ │
│  │  │  │EKS Node│      │         │      │EKS Node│ │        │ │
│  │  │  │  ┌───┐ │      │         │      │  ┌───┐ │ │        │ │
│  │  │  │  │Pod│ │      │         │      │  │Pod│ │ │        │ │
│  │  │  │  └───┘ │      │         │      │  └───┘ │ │        │ │
│  │  │  └────────┘      │         │      └────────┘ │        │ │
│  │  └──────────────────┘         └──────────────────┘        │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                   Database Subnets                          │ │
│  │  ┌──────────────────┐         ┌──────────────────┐        │ │
│  │  │  AZ-1 Database   │         │  AZ-2 Database   │        │ │
│  │  │  10.0.21.0/24    │         │  10.0.22.0/24    │        │ │
│  │  │                  │         │                  │        │ │
│  │  │     ┌─────┐      │         │      ┌─────┐    │        │ │
│  │  │     │ RDS │      │         │      │ RDS │    │        │ │
│  │  │     │(Pri)│      │         │      │(Sec)│    │        │ │
│  │  │     └─────┘      │         │      └─────┘    │        │ │
│  │  └──────────────────┘         └──────────────────┘        │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

**Network Flow:**
1. Internet → ALB (public subnets)
2. ALB → ECS tasks / EKS pods (private subnets)
3. ECS/EKS → RDS (database subnets)
4. ECS/EKS → Internet via NAT Gateway (for ECR pulls, etc.)

**Design Rationale:**
- **Multi-AZ**: High availability across 2 availability zones
- **Private Subnets**: Workloads not directly exposed to internet
- **Database Isolation**: RDS in separate subnets with restricted access
- **Shared VPC**: Reuses existing network infrastructure (cost optimization)

---

## Traffic Routing Architecture

### Weighted Routing Mechanism

```
                    ┌─────────────┐
                    │     ALB     │
                    │  Listener   │
                    │  (Port 80)  │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │ Listener    │
                    │   Rule      │
                    │ Priority:100│
                    └──────┬──────┘
                           │
              ┌────────────▼────────────┐
              │  Forward Action         │
              │  (Weighted Routing)     │
              └────────────┬────────────┘
                           │
          ┌────────────────┴────────────────┐
          │                                 │
     ┌────▼────────┐                  ┌────▼────────┐
     │ ECS Target  │                  │ EKS Target  │
     │   Group     │                  │   Group     │
     │             │                  │             │
     │ Weight: 100 │                  │ Weight: 0   │
     │    ↓        │                  │    ↑        │
     │ Weight: 0   │                  │ Weight: 100 │
     └────┬────────┘                  └────┬────────┘
          │                                 │
     ┌────▼────────┐                  ┌────▼────────┐
     │ ECS Tasks   │                  │  EKS Pods   │
     │ 10.0.11.10  │                  │ 10.0.11.50  │
     │ 10.0.12.10  │                  │ 10.0.12.50  │
     └─────────────┘                  └─────────────┘
```

### Traffic Shifting Phases

**Phase 0: Validation (0% EKS)**
```
ALB → 100% ECS, 0% EKS
Purpose: Verify EKS is healthy before routing traffic
Duration: 1-2 hours
```

**Phase 1: Canary (10% EKS)**
```
ALB → 90% ECS, 10% EKS
Purpose: Test with small amount of real traffic
Duration: 2-4 hours
```

**Phase 2-4: Gradual Increase**
```
Phase 2: 75% ECS, 25% EKS (2 hours)
Phase 3: 50% ECS, 50% EKS (2 hours)
Phase 4: 25% ECS, 75% EKS (2 hours)
```

**Phase 5: Full Migration (100% EKS)**
```
ALB → 0% ECS, 100% EKS
Purpose: Complete migration for testing
Duration: 24-48 hours
```

**Rollback: Return to ECS**
```
ALB → 100% ECS, 0% EKS
Time: < 30 seconds
```

---

## Security Architecture

### Security Groups

```
┌─────────────────────────────────────────────────────────┐
│                    ALB Security Group                    │
│  Inbound:  0.0.0.0/0:80, 0.0.0.0/0:443                 │
│  Outbound: ECS SG, EKS Node SG                          │
└────────────────────┬────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
┌───────▼──────────┐      ┌──────▼────────────┐
│  ECS Task SG     │      │  EKS Node SG      │
│  Inbound:        │      │  Inbound:         │
│   - ALB SG:80    │      │   - ALB SG:80     │
│  Outbound:       │      │   - Cluster SG    │
│   - RDS SG:5432  │      │   - Self          │
│   - 0.0.0.0/0    │      │  Outbound:        │
└───────┬──────────┘      │   - RDS SG:5432   │
        │                 │   - 0.0.0.0/0     │
        │                 └──────┬────────────┘
        │                        │
        │                 ┌──────▼────────────┐
        │                 │ EKS Cluster SG    │
        │                 │  Inbound:         │
        │                 │   - Node SG:443   │
        │                 │  Outbound:        │
        │                 │   - Node SG       │
        │                 └───────────────────┘
        │                        │
        └────────────┬───────────┘
                     │
            ┌────────▼──────────┐
            │    RDS SG         │
            │  Inbound:         │
            │   - ECS SG:5432   │
            │   - EKS Node:5432 │
            │  Outbound: None   │
            └───────────────────┘
```

### IAM Roles

```
┌─────────────────────────────────────────────────────────┐
│                    EKS Cluster Role                      │
│  Trust: eks.amazonaws.com                               │
│  Policies:                                              │
│   - AmazonEKSClusterPolicy                             │
│   - AmazonEKSVPCResourceController                     │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                    EKS Node Role                         │
│  Trust: ec2.amazonaws.com                               │
│  Policies:                                              │
│   - AmazonEKSWorkerNodePolicy                          │
│   - AmazonEKS_CNI_Policy                               │
│   - AmazonEC2ContainerRegistryReadOnly                 │
│   - CloudWatchAgentServerPolicy                        │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│              ALB Controller Role (IRSA)                  │
│  Trust: OIDC Provider (EKS)                             │
│  Condition: ServiceAccount=aws-load-balancer-controller │
│  Policies:                                              │
│   - Custom ALB Controller Policy                        │
│     (EC2, ELB, WAF, Shield, ACM permissions)           │
└─────────────────────────────────────────────────────────┘
```

**Security Best Practices:**
- ✅ Least privilege IAM policies
- ✅ Security groups with minimal required access
- ✅ Private subnets for workloads
- ✅ Secrets stored in Kubernetes Secrets (not in code)
- ✅ IRSA for pod-level IAM permissions
- ✅ Network isolation between layers

---

## Monitoring Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      CloudWatch                          │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │              Container Insights                     │ │
│  │  - Cluster metrics (CPU, memory, pod count)        │ │
│  │  - Node metrics (CPU, memory, disk, network)       │ │
│  │  - Pod metrics (CPU, memory, restarts)             │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │                 Log Groups                          │ │
│  │  - /aws/eks/cluster (control plane logs)           │ │
│  │  - /aws/eks/application (pod logs via Fluent Bit)  │ │
│  │  - /aws/containerinsights/performance              │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │                  Dashboards                         │ │
│  │  - ECS vs EKS Comparison                           │ │
│  │  - CPU/Memory utilization                          │ │
│  │  - Request count and latency                       │ │
│  │  - Error rates (4XX, 5XX)                          │ │
│  │  - Target health                                   │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │                    Alarms                           │ │
│  │  - Low node count                                  │ │
│  │  - High CPU/memory utilization                     │ │
│  │  - Unhealthy targets                               │ │
│  │  - High 5XX error rate                             │ │
│  │  → SNS Topic → Email notifications                 │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                           ▲
                           │
        ┌──────────────────┴──────────────────┐
        │                                     │
┌───────▼──────────┐              ┌──────────▼────────┐
│   EKS Cluster    │              │    Fluent Bit     │
│  (Metrics API)   │              │   (DaemonSet)     │
│                  │              │                   │
│  Container       │              │  Collects logs    │
│  Insights Agent  │              │  from all pods    │
└──────────────────┘              └───────────────────┘
```

---

## Architecture States

### State 1: Pre-Migration (Current)

```
Users → ALB → ECS (100%) → RDS
              ↓
            ECR
```

**Characteristics:**
- ECS handles all traffic
- No EKS resources exist
- Baseline cost: ~$8/week

### State 2: Deployment (Transition)

```
Users → ALB → ECS (100%) → RDS
              ↓            ↑
            ECR            │
              ↓            │
            EKS (0%) ──────┘
```

**Characteristics:**
- EKS deployed but not receiving traffic
- Validation and testing phase
- Cost: ~$26/week (ECS + EKS)

### State 3: Migration (Parallel)

```
Users → ALB ─┬→ ECS (0-100%) → RDS
             │                 ↑
             └→ EKS (0-100%) ──┘
                  ↓
                ECR
```

**Characteristics:**
- Traffic split between ECS and EKS
- Gradual weight adjustment
- Both environments active
- Cost: ~$26/week

### State 4: Post-Rollback (Return)

```
Users → ALB → ECS (100%) → RDS
              ↓
            ECR

[EKS resources deleted]
```

**Characteristics:**
- Back to original state
- EKS completely removed
- Cost: ~$8/week

---

## Design Principles

### 1. Isolation

**Principle:** EKS and ECS deployments are completely independent.

**Implementation:**
- Separate target groups
- Separate security groups
- Separate IAM roles
- No shared state

**Benefit:** Can destroy EKS without affecting ECS.

### 2. Reversibility

**Principle:** Can rollback to ECS at any time.

**Implementation:**
- ECS remains unchanged throughout
- Traffic routing controlled by ALB weights
- Instant rollback (< 30 seconds)

**Benefit:** Zero risk to production ECS environment.

### 3. Cost-Consciousness

**Principle:** Minimize costs during exploration.

**Implementation:**
- Use t3.micro instances (free tier)
- Optimize log retention
- Reuse existing resources (VPC, ALB, RDS, ECR)
- Plan for short-term usage (1 week)

**Benefit:** Exploration costs ~$18-25/week instead of $40+/week.

### 4. Production-Ready Patterns

**Principle:** Follow AWS best practices despite temporary nature.

**Implementation:**
- Multi-AZ deployment
- Health checks and probes
- Auto-scaling capabilities
- Monitoring and logging
- Security best practices

**Benefit:** Learn production-grade EKS patterns.

### 5. Modularity

**Principle:** Components are loosely coupled and reusable.

**Implementation:**
- Separate Terraform modules
- Clear interfaces and outputs
- No hard-coded values
- Environment-specific configurations

**Benefit:** Easy to adapt for different use cases.

---

## Component Interactions

### Request Flow

```
1. User Request
   ↓
2. ALB (weighted routing decision)
   ↓
3a. ECS Task          OR    3b. EKS Pod
   ↓                          ↓
4. Application Logic    4. Application Logic
   ↓                          ↓
5. RDS Query            5. RDS Query
   ↓                          ↓
6. Response             6. Response
   ↓                          ↓
7. ALB                  7. ALB
   ↓                          ↓
8. User                 8. User
```

### Deployment Flow

```
1. Terraform Apply
   ↓
2. Create EKS Cluster (10-12 min)
   ↓
3. Create Node Group (5-7 min)
   ↓
4. Deploy Kubernetes Resources (1-2 min)
   ↓
5. Create ALB Target Group
   ↓
6. Configure Weighted Routing (0% EKS)
   ↓
7. Install ALB Controller
   ↓
8. Verify Deployment
   ↓
9. Begin Traffic Shifting
```

---

## Scalability Considerations

### Current Scale

- **ECS:** 2 tasks, 0.5 vCPU, 1 GB RAM each
- **EKS:** 2 nodes (t3.micro), 2 pods, 0.25 vCPU, 512 MB RAM each
- **RDS:** Shared database
- **Traffic:** Low to moderate

### Scaling Options

**Horizontal Pod Autoscaling:**
- Min: 2 pods
- Max: 3 pods (limited by node capacity)
- Triggers: CPU > 70%, Memory > 80%

**Cluster Autoscaling:**
- Not implemented (cost optimization)
- Can be added for production

**Node Scaling:**
- Manual: Adjust desired_size in Terraform
- Automatic: Add Cluster Autoscaler

---

## Disaster Recovery

### Failure Scenarios

**Scenario 1: EKS Pod Failure**
- Detection: Liveness probe fails
- Action: Kubernetes restarts pod automatically
- Impact: Minimal (other pod handles traffic)
- Recovery Time: 30-60 seconds

**Scenario 2: EKS Node Failure**
- Detection: Node becomes NotReady
- Action: Pods rescheduled to healthy node
- Impact: Temporary capacity reduction
- Recovery Time: 2-3 minutes

**Scenario 3: EKS Cluster Failure**
- Detection: All pods unhealthy
- Action: Shift 100% traffic to ECS
- Impact: None (ECS handles all traffic)
- Recovery Time: < 30 seconds

**Scenario 4: RDS Failure**
- Detection: Database connection errors
- Action: RDS automatic failover to standby
- Impact: Both ECS and EKS affected
- Recovery Time: 1-2 minutes (RDS Multi-AZ)

---

## Performance Characteristics

### Expected Latency

- **ALB → ECS:** ~5-10ms
- **ALB → EKS:** ~5-10ms (similar to ECS)
- **Pod → RDS:** ~2-5ms (same VPC)
- **Total Response Time:** ~50-200ms (application dependent)

### Throughput

- **ALB:** 1000s of requests/second
- **ECS:** Limited by task count and resources
- **EKS:** Limited by pod count and node resources
- **RDS:** Depends on instance type

---

## Cost Architecture

### Cost Breakdown

```
┌─────────────────────────────────────────┐
│         EKS Control Plane               │
│         $0.10/hour                      │
│         (Not free tier eligible)        │
└─────────────────────────────────────────┘
                  +
┌─────────────────────────────────────────┐
│         EC2 Nodes (2× t3.micro)         │
│         $0.00/hour                      │
│         (Free tier eligible)            │
└─────────────────────────────────────────┘
                  +
┌─────────────────────────────────────────┐
│         EBS Volumes (40 GB)             │
│         ~$0.02/hour                     │
│         (Partial free tier)             │
└─────────────────────────────────────────┘
                  +
┌─────────────────────────────────────────┐
│         CloudWatch Logs                 │
│         ~$0.15/hour                     │
│         (Partial free tier)             │
└─────────────────────────────────────────┘
                  =
┌─────────────────────────────────────────┐
│         Total: ~$0.27/hour              │
│         Weekly: ~$18-25                 │
└─────────────────────────────────────────┘
```

### Shared Resources (No Additional Cost)

- VPC and subnets
- NAT Gateway (existing)
- ALB (existing)
- RDS (existing)
- ECR (existing)

---

## Summary

This architecture provides:

✅ **Safe exploration** of EKS without risking ECS  
✅ **Gradual migration** with instant rollback capability  
✅ **Cost optimization** through resource sharing and free tier usage  
✅ **Production patterns** for learning and evaluation  
✅ **Complete isolation** between ECS and EKS  
✅ **High availability** with multi-AZ deployment  
✅ **Comprehensive monitoring** for comparison and troubleshooting  

**Ready to deploy?** See the [Quick Start Guide](../README.md#quick-start-terraform)
