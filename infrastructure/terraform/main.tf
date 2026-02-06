# Singha Loyalty System - Main Terraform Configuration
# This is the root module that orchestrates all infrastructure components

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Uncomment and configure for remote state management
  # backend "s3" {
  #   bucket         = "singha-loyalty-terraform-state"
  #   key            = "terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "singha-loyalty-terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        Project     = var.project_name
        Environment = var.environment
        ManagedBy   = "Terraform"
      },
      var.additional_tags
    )
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  azs          = slice(data.aws_availability_zones.available.names, 0, 2)
}

# Security Groups Module
module "security_groups" {
  source = "./modules/security-groups"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
}

# RDS Module
module "rds" {
  source = "./modules/rds"

  project_name            = var.project_name
  environment             = var.environment
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  rds_security_group_id   = module.security_groups.rds_security_group_id
  db_username             = var.db_username
  db_password             = var.db_password
  db_instance_class       = var.db_instance_class
  allocated_storage       = var.allocated_storage
  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
}

# ECR Module
module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment
}

# ALB Module
module "alb" {
  source = "./modules/alb"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = module.security_groups.alb_security_group_id
}

# ECS Module
module "ecs" {
  source = "./modules/ecs"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  ecs_security_group_id = module.security_groups.ecs_security_group_id
  target_group_arn      = module.alb.target_group_arn
  container_image       = var.container_image != "" ? var.container_image : "${module.ecr.repository_url}:latest"
  container_cpu         = var.container_cpu
  container_memory      = var.container_memory
  desired_count         = var.desired_count

  # Environment variables
  db_host     = module.rds.db_endpoint
  db_port     = "3306"
  db_name     = module.rds.db_name
  db_username = var.db_username
  db_password = var.db_password
  jwt_secret  = var.jwt_secret
  cors_origin = var.cors_origin

  aws_region = var.aws_region

  # Auto scaling
  enable_autoscaling     = var.enable_autoscaling
  min_capacity           = var.min_capacity
  max_capacity           = var.max_capacity
  cpu_target_value       = var.cpu_target_value
  memory_target_value    = var.memory_target_value
  use_spot_instances     = var.use_spot_instances
  spot_weight            = var.spot_weight
  enable_container_insights = var.enable_container_insights
  log_retention_days     = var.log_retention_days
}

# S3 Module for Frontend
module "s3_frontend" {
  source = "./modules/s3-frontend"

  project_name = var.project_name
  environment  = var.environment
}

# CloudFront Module for Frontend
module "cloudfront" {
  source = "./modules/cloudfront"

  project_name          = var.project_name
  environment           = var.environment
  s3_bucket_id          = module.s3_frontend.bucket_id
  s3_bucket_domain_name = module.s3_frontend.bucket_domain_name
  s3_bucket_arn         = module.s3_frontend.bucket_arn
  alb_dns_name          = module.alb.alb_dns_name
  price_class           = var.cloudfront_price_class
}

# CI/CD Pipeline Module
module "cicd_pipeline" {
  source = "./modules/cicd-pipeline"
  
  # Only create if CI/CD is enabled
  count = var.enable_cicd_pipeline ? 1 : 0

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  # GitHub Configuration
  github_connection_arn = var.github_connection_arn
  github_repository     = var.github_repository
  github_branch         = var.github_branch

  # ECR Configuration
  ecr_repository_name = module.ecr.repository_name

  # ECS Configuration
  ecs_cluster_name = module.ecs.cluster_name
  ecs_service_name = module.ecs.service_name

  # CodeBuild Configuration
  codebuild_compute_type = var.codebuild_compute_type
  codebuild_image        = var.codebuild_image
  buildspec_path         = var.buildspec_path

  # Monitoring
  log_retention_days = var.log_retention_days
}
