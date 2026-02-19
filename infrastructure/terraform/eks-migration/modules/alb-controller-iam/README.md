# AWS Load Balancer Controller IAM Module

This module creates an IAM role for the AWS Load Balancer Controller using IAM Roles for Service Accounts (IRSA). This allows the controller running in Kubernetes to assume an IAM role and manage AWS load balancer resources securely without storing AWS credentials.

## Features

- Creates IAM role with OIDC provider trust policy
- Implements comprehensive IAM policy for ALB/NLB management
- Supports EC2, ELB, WAF, Shield, and ACM operations
- Follows least privilege security principles

## Usage

```hcl
module "alb_controller_iam" {
  source = "./modules/alb-controller-iam"

  cluster_name       = "backend-eks-exploration"
  oidc_provider_arn  = module.eks_cluster.oidc_provider_arn

  tags = {
    Environment = "exploration"
    Project     = "eks-migration"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | Name of the EKS cluster | `string` | n/a | yes |
| oidc_provider_arn | ARN of the OIDC provider for the EKS cluster | `string` | n/a | yes |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| role_arn | ARN of the IAM role for AWS Load Balancer Controller |
| role_name | Name of the IAM role for AWS Load Balancer Controller |
| policy_arn | ARN of the IAM policy for AWS Load Balancer Controller |

## Well-Architected Framework Alignment

### Security
- **Least Privilege**: IAM policy grants only necessary permissions for ALB controller operations
- **IRSA**: Uses IAM Roles for Service Accounts instead of storing credentials in pods
- **Scoped Permissions**: Conditions limit actions to specific AWS services

### Operational Excellence
- **Infrastructure as Code**: All IAM resources defined in Terraform
- **Modular Design**: Reusable module for different EKS clusters
- **Clear Documentation**: Comprehensive README and inline comments

## Notes

- The IAM role is specifically configured for the `aws-load-balancer-controller` service account in the `kube-system` namespace
- The policy includes permissions for ALB, NLB, WAF, Shield, and ACM
- OIDC provider must be created before this module can be used
- The controller must be deployed with the service account annotation pointing to this role ARN
