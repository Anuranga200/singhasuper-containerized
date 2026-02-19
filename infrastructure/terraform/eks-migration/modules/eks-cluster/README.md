# EKS Cluster Module

This module creates an Amazon EKS cluster with all necessary supporting resources.

## Resources Created

- **EKS Cluster**: Managed Kubernetes control plane
- **IAM Role**: Cluster service role with required policies
- **Security Group**: Cluster security group for control plane communication
- **OIDC Provider**: For IAM Roles for Service Accounts (IRSA)
- **CloudWatch Log Groups**: For cluster control plane logs

## Features

- Configurable Kubernetes version
- Public and private API endpoint access
- Comprehensive CloudWatch logging (api, audit, authenticator, controllerManager, scheduler)
- OIDC provider for service account authentication
- Security group with proper ingress/egress rules

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_name | Name of the EKS cluster | string | - | yes |
| kubernetes_version | Kubernetes version | string | "1.28" | no |
| vpc_id | VPC ID where cluster will be created | string | - | yes |
| subnet_ids | List of subnet IDs for cluster | list(string) | - | yes |
| endpoint_public_access | Enable public API endpoint | bool | true | no |
| endpoint_private_access | Enable private API endpoint | bool | true | no |
| enabled_cluster_log_types | Control plane log types | list(string) | ["api", "audit", ...] | no |
| tags | Tags to apply to resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | EKS cluster ID |
| cluster_endpoint | EKS cluster API endpoint |
| cluster_certificate_authority_data | Base64 encoded certificate data |
| cluster_security_group_id | Security group ID for cluster |
| cluster_iam_role_arn | IAM role ARN for cluster |
| oidc_provider_arn | OIDC provider ARN for IRSA |

## Files

- `main.tf` - EKS cluster resource
- `iam.tf` - IAM roles and policies
- `security-groups.tf` - Security group configuration
- `variables.tf` - Input variables
- `outputs.tf` - Output values

## Usage

```hcl
module "eks_cluster" {
  source = "../../modules/eks-cluster"
  
  cluster_name       = "my-eks-cluster"
  kubernetes_version = "1.28"
  vpc_id             = "vpc-xxxxx"
  subnet_ids         = ["subnet-xxxxx", "subnet-yyyyy"]
  
  tags = {
    Environment = "production"
  }
}
```

## Well-Architected Framework Alignment

- **Security**: Least privilege IAM roles, private endpoint access, security groups
- **Reliability**: Multi-AZ deployment, comprehensive logging
- **Operational Excellence**: CloudWatch logging for troubleshooting
- **Cost Optimization**: Single cluster, no unnecessary resources
