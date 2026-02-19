# Root Module Composition for EKS Migration
# This file orchestrates all modules to deploy the complete EKS infrastructure

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Data source to get existing VPC
data "aws_vpc" "existing" {
  id = var.vpc_id
}

# Data source to get existing subnets
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  
  tags = {
    Type = "private"
  }
}

# Data source to get existing RDS security group
data "aws_security_group" "rds" {
  id = var.rds_security_group_id
}

# Data source to get existing ALB
data "aws_lb" "existing" {
  arn = var.alb_arn
}

# Data source to get existing ALB listener
data "aws_lb_listener" "existing" {
  arn = var.alb_listener_arn
}

# Data source to get existing ECS target group
data "aws_lb_target_group" "ecs" {
  arn = var.ecs_target_group_arn
}

# Module: EKS Cluster
# Creates the EKS control plane with IAM roles, security groups, and OIDC provider
module "eks_cluster" {
  source = "../../modules/eks-cluster"
  
  cluster_name            = var.cluster_name
  kubernetes_version      = var.kubernetes_version
  vpc_id                  = var.vpc_id
  subnet_ids              = var.subnet_ids
  endpoint_public_access  = var.endpoint_public_access
  endpoint_private_access = var.endpoint_private_access
  enabled_cluster_log_types = var.enabled_cluster_log_types
  
  tags = {
    Environment = "exploration"
    Purpose     = "EKS-Migration-Testing"
  }
}

# Module: EKS Node Group
# Creates worker nodes with IAM roles, security groups, and RDS access
module "eks_node_group" {
  source = "../../modules/eks-node-group"
  
  # Dependencies
  cluster_name = module.eks_cluster.cluster_id
  
  # Node group configuration
  node_group_name        = var.node_group_name
  subnet_ids             = var.subnet_ids
  instance_types         = var.instance_types
  capacity_type          = var.capacity_type
  desired_size           = var.desired_size
  min_size               = var.min_size
  max_size               = var.max_size
  disk_size              = var.disk_size
  
  # Node labels
  labels = {
    environment = "exploration"
    workload    = "backend"
  }
  
  # RDS access
  rds_security_group_id = var.rds_security_group_id
  
  tags = {
    Environment = "exploration"
    NodeGroup   = "backend-nodes"
  }
  
  # Ensure cluster is created before node group
  depends_on = [module.eks_cluster]
}

# Module: Kubernetes Resources
# Deploys application resources (namespace, deployment, service, ingress, secrets)
module "kubernetes_resources" {
  source = "../../modules/kubernetes-resources"
  
  # Cluster connection
  cluster_endpoint       = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = module.eks_cluster.cluster_certificate_authority_data
  cluster_name           = module.eks_cluster.cluster_id
  
  # Application configuration
  namespace       = var.namespace
  app_name        = var.app_name
  container_image = var.container_image
  container_port  = var.container_port
  replicas        = var.replicas
  
  # Resource limits
  cpu_request    = var.cpu_request
  memory_request = var.memory_request
  cpu_limit      = var.cpu_limit
  memory_limit   = var.memory_limit
  
  # Database credentials
  db_host     = var.db_host
  db_name     = var.db_name
  db_user     = var.db_user
  db_password = var.db_password
  jwt_secret  = var.jwt_secret
  
  # Health checks
  health_check_path = var.health_check_path
  
  # Optional features
  enable_hpa = var.enable_hpa
  
  # Ensure nodes are ready before deploying workloads
  depends_on = [module.eks_node_group]
}

# Module: ALB Integration
# Creates EKS target group and configures weighted routing between ECS and EKS
module "alb_integration" {
  source = "../../modules/alb-integration"
  
  # ALB configuration
  alb_arn          = var.alb_arn
  alb_listener_arn = var.alb_listener_arn
  vpc_id           = var.vpc_id
  
  # Target group configuration
  target_group_name = var.eks_target_group_name
  health_check_path = var.health_check_path
  health_check_interval = var.health_check_interval
  health_check_timeout  = var.health_check_timeout
  healthy_threshold     = var.healthy_threshold
  unhealthy_threshold   = var.unhealthy_threshold
  
  # Traffic routing weights
  ecs_target_group_arn = var.ecs_target_group_arn
  eks_weight           = var.eks_weight
  ecs_weight           = var.ecs_weight
  
  tags = {
    Environment = "exploration"
    TargetGroup = "eks-backend"
  }
  
  # Ensure Kubernetes resources are deployed before ALB integration
  depends_on = [module.kubernetes_resources]
}
