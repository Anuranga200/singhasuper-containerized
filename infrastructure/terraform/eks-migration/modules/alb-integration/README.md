# ALB Integration Module

This module integrates EKS with an existing Application Load Balancer for traffic routing.

## Resources Created

- **Target Group**: EKS target group with IP target type
- **Listener Rule**: Weighted routing rule between ECS and EKS
- **Health Check Configuration**: Matching application endpoints

## Features

- IP target type for direct pod routing
- Weighted traffic distribution between ECS and EKS
- Configurable health checks
- Fast deregistration for quick rollback
- Preserves existing ECS routing

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| alb_arn | ARN of existing ALB | string | - | yes |
| alb_listener_arn | ARN of ALB listener | string | - | yes |
| vpc_id | VPC ID | string | - | yes |
| target_group_name | Name for EKS target group | string | "eks-backend-tg" | no |
| health_check_path | Health check path | string | "/health" | no |
| health_check_interval | Health check interval (seconds) | number | 15 | no |
| health_check_timeout | Health check timeout (seconds) | number | 5 | no |
| healthy_threshold | Healthy threshold count | number | 2 | no |
| unhealthy_threshold | Unhealthy threshold count | number | 2 | no |
| ecs_target_group_arn | ARN of ECS target group | string | - | yes |
| eks_weight | Traffic weight for EKS (0-100) | number | 0 | no |
| ecs_weight | Traffic weight for ECS (0-100) | number | 100 | no |
| tags | Tags for resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| eks_target_group_arn | ARN of EKS target group |
| eks_target_group_name | Name of EKS target group |
| listener_rule_arn | ARN of listener rule |

## Files

- `main.tf` - Target group and listener rule
- `data.tf` - Data sources for existing ALB
- `variables.tf` - Input variables
- `outputs.tf` - Output values

## Usage

```hcl
module "alb_integration" {
  source = "../../modules/alb-integration"
  
  alb_arn              = "arn:aws:elasticloadbalancing:..."
  alb_listener_arn     = "arn:aws:elasticloadbalancing:..."
  vpc_id               = "vpc-xxxxx"
  ecs_target_group_arn = "arn:aws:elasticloadbalancing:..."
  
  # Start with 0% to EKS, 100% to ECS
  eks_weight = 0
  ecs_weight = 100
}
```

## Traffic Shifting Strategy

Gradually shift traffic from ECS to EKS:

1. **Initial**: ECS 100%, EKS 0% (safe deployment)
2. **Testing**: ECS 90%, EKS 10% (initial validation)
3. **Gradual**: ECS 75%, EKS 25% → ECS 50%, EKS 50%
4. **Full**: ECS 0%, EKS 100% (complete migration)
5. **Rollback**: ECS 100%, EKS 0% (return to original)

Monitor metrics between each shift!

## Well-Architected Framework Alignment

- **Reliability**: Health checks, gradual traffic shifting
- **Performance Efficiency**: IP target type for direct routing
- **Operational Excellence**: Easy traffic control, fast rollback
- **Cost Optimization**: Reuses existing ALB
