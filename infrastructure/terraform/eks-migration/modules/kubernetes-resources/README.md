# Kubernetes Resources Module

This module deploys Kubernetes application resources using the Kubernetes Terraform provider.

## Resources Created

- **Namespace**: Isolated namespace for backend application
- **Secret**: Database credentials and JWT secret
- **Deployment**: Pod deployment with replicas and health checks
- **Service**: ClusterIP service for internal routing
- **Ingress**: AWS Load Balancer Controller ingress
- **PodDisruptionBudget**: Ensures minimum pod availability
- **HorizontalPodAutoscaler** (optional): Auto-scaling based on CPU/memory

## Features

- Pod anti-affinity for multi-node distribution
- Resource requests and limits for stability
- Comprehensive health checks (liveness, readiness, startup)
- Zero-downtime rolling updates
- Secrets management for sensitive data
- ALB integration via ingress annotations
- Optional horizontal pod autoscaling

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_endpoint | EKS cluster endpoint | string | - | yes |
| cluster_ca_certificate | Cluster CA certificate | string | - | yes |
| cluster_name | EKS cluster name | string | - | yes |
| namespace | Kubernetes namespace | string | "backend" | no |
| app_name | Application name | string | "backend-api" | no |
| container_image | ECR image URI | string | - | yes |
| container_port | Container port | number | 3000 | no |
| replicas | Number of replicas | number | 2 | no |
| cpu_request | CPU request | string | "250m" | no |
| memory_request | Memory request | string | "512Mi" | no |
| cpu_limit | CPU limit | string | "500m" | no |
| memory_limit | Memory limit | string | "1Gi" | no |
| db_host | Database host | string | - | yes |
| db_name | Database name | string | - | yes |
| db_user | Database user | string | - | yes |
| db_password | Database password | string | - | yes |
| jwt_secret | JWT secret | string | - | yes |
| health_check_path | Health check path | string | "/health" | no |
| enable_hpa | Enable HPA | bool | false | no |

## Outputs

| Name | Description |
|------|-------------|
| namespace | Kubernetes namespace |
| deployment_name | Deployment name |
| service_name | Service name |
| ingress_name | Ingress name |

## Files

- `main.tf` - Kubernetes provider configuration
- `namespace.tf` - Namespace resource
- `secrets.tf` - Secret resource
- `deployment.tf` - Deployment resource
- `service.tf` - Service resource
- `ingress.tf` - Ingress resource
- `pdb.tf` - PodDisruptionBudget
- `hpa.tf` - HorizontalPodAutoscaler (optional)
- `variables.tf` - Input variables
- `outputs.tf` - Output values

## Usage

```hcl
module "kubernetes_resources" {
  source = "../../modules/kubernetes-resources"
  
  cluster_endpoint       = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = module.eks_cluster.cluster_certificate_authority_data
  cluster_name           = module.eks_cluster.cluster_id
  
  container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/backend:latest"
  replicas        = 2
  
  db_host     = "backend-db.xxxxx.us-east-1.rds.amazonaws.com"
  db_name     = "backend_production"
  db_user     = "backend_user"
  db_password = var.db_password
  jwt_secret  = var.jwt_secret
}
```

## Well-Architected Framework Alignment

- **Reliability**: Pod anti-affinity, PDB, health checks, zero-downtime updates
- **Security**: Secrets for sensitive data, resource limits
- **Performance Efficiency**: Resource requests/limits, optional HPA
- **Operational Excellence**: Comprehensive health checks, proper labeling
