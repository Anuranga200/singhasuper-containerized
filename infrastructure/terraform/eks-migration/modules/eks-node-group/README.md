# EKS Node Group Module

This module creates an Amazon EKS managed node group with worker nodes.

## Resources Created

- **EKS Node Group**: Managed worker nodes
- **IAM Role**: Node instance role with required policies
- **Security Group**: Node security group for pod communication
- **Security Group Rules**: RDS access, inter-node communication
- **Launch Template** (optional): Custom node configuration

## Features

- Configurable instance types (t3.small, t3.micro for free tier)
- Auto-scaling configuration (desired, min, max)
- Multi-AZ deployment for high availability
- RDS database access via security group rules
- ECR image pull permissions
- CloudWatch logging and metrics
- Node labels for workload identification

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_name | Name of the EKS cluster | string | - | yes |
| node_group_name | Name of the node group | string | - | yes |
| subnet_ids | List of subnet IDs for nodes | list(string) | - | yes |
| instance_types | List of instance types | list(string) | ["t3.small"] | no |
| capacity_type | ON_DEMAND or SPOT | string | "ON_DEMAND" | no |
| desired_size | Desired number of nodes | number | 2 | no |
| min_size | Minimum number of nodes | number | 2 | no |
| max_size | Maximum number of nodes | number | 3 | no |
| disk_size | Disk size in GB | number | 20 | no |
| labels | Kubernetes labels for nodes | map(string) | {} | no |
| rds_security_group_id | RDS security group ID | string | - | yes |
| tags | Tags to apply to resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| node_group_id | Node group ID |
| node_group_arn | Node group ARN |
| node_group_status | Node group status |
| node_security_group_id | Security group ID for nodes |
| node_iam_role_arn | IAM role ARN for nodes |

## Files

- `main.tf` - Node group resource
- `iam.tf` - IAM roles and policies
- `security-groups.tf` - Security group configuration
- `variables.tf` - Input variables
- `outputs.tf` - Output values
- `launch-template.tf` (optional) - Custom launch template

## Usage

```hcl
module "eks_node_group" {
  source = "../../modules/eks-node-group"
  
  cluster_name          = "my-eks-cluster"
  node_group_name       = "backend-nodes"
  subnet_ids            = ["subnet-xxxxx", "subnet-yyyyy"]
  instance_types        = ["t3.small"]
  desired_size          = 2
  rds_security_group_id = "sg-xxxxx"
  
  labels = {
    workload = "backend"
  }
}
```

## Well-Architected Framework Alignment

- **Reliability**: Multi-AZ deployment, auto-scaling
- **Security**: Least privilege IAM, security groups, private subnets
- **Performance Efficiency**: Right-sized instances, configurable scaling
- **Cost Optimization**: t3.small/t3.micro for free tier eligibility
- **Sustainability**: Appropriate instance sizing
