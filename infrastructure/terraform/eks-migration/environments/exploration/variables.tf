# Variables for EKS Migration Root Module
# This file defines all input variables for the Terraform configuration

# ============================================================================
# AWS Configuration
# ============================================================================

variable "aws_region" {
  type        = string
  description = "AWS region where resources will be created"
  default     = "us-east-1"
}

# ============================================================================
# Network Configuration
# ============================================================================

variable "vpc_id" {
  type        = string
  description = "ID of the existing VPC where EKS will be deployed"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for EKS cluster and nodes (must span at least 2 AZs)"
}

variable "rds_security_group_id" {
  type        = string
  description = "Security group ID of the existing RDS database"
}

# ============================================================================
# EKS Cluster Configuration
# ============================================================================

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
  default     = "backend-eks-exploration"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version for the EKS cluster"
  default     = "1.28"
}

variable "endpoint_public_access" {
  type        = bool
  description = "Enable public API endpoint access for kubectl"
  default     = true
}

variable "endpoint_private_access" {
  type        = bool
  description = "Enable private API endpoint access for nodes"
  default     = true
}

variable "enabled_cluster_log_types" {
  type        = list(string)
  description = "List of control plane log types to enable in CloudWatch"
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

# ============================================================================
# EKS Node Group Configuration
# ============================================================================

variable "node_group_name" {
  type        = string
  description = "Name of the EKS node group"
  default     = "backend-nodes"
}

variable "instance_types" {
  type        = list(string)
  description = "List of EC2 instance types for nodes (t3.small recommended, t3.micro for free tier)"
  default     = ["t3.small"]
}

variable "capacity_type" {
  type        = string
  description = "Type of capacity (ON_DEMAND or SPOT)"
  default     = "ON_DEMAND"
  
  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "Capacity type must be either ON_DEMAND or SPOT"
  }
}

variable "desired_size" {
  type        = number
  description = "Desired number of nodes in the node group"
  default     = 2
}

variable "min_size" {
  type        = number
  description = "Minimum number of nodes in the node group"
  default     = 2
}

variable "max_size" {
  type        = number
  description = "Maximum number of nodes in the node group"
  default     = 3
}

variable "disk_size" {
  type        = number
  description = "Disk size in GB for each node"
  default     = 20
}

# ============================================================================
# Kubernetes Application Configuration
# ============================================================================

variable "namespace" {
  type        = string
  description = "Kubernetes namespace for the backend application"
  default     = "backend"
}

variable "app_name" {
  type        = string
  description = "Name of the application"
  default     = "backend-api"
}

variable "container_image" {
  type        = string
  description = "Full ECR image URI (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com/backend:latest)"
}

variable "container_port" {
  type        = number
  description = "Port on which the container listens"
  default     = 3000
}

variable "replicas" {
  type        = number
  description = "Number of pod replicas"
  default     = 2
}

# ============================================================================
# Resource Limits
# ============================================================================

variable "cpu_request" {
  type        = string
  description = "CPU request for each pod (e.g., 250m = 0.25 vCPU)"
  default     = "250m"
}

variable "memory_request" {
  type        = string
  description = "Memory request for each pod (e.g., 512Mi)"
  default     = "512Mi"
}

variable "cpu_limit" {
  type        = string
  description = "CPU limit for each pod (e.g., 500m = 0.5 vCPU)"
  default     = "500m"
}

variable "memory_limit" {
  type        = string
  description = "Memory limit for each pod (e.g., 1Gi)"
  default     = "1Gi"
}

# ============================================================================
# Database Configuration
# ============================================================================

variable "db_host" {
  type        = string
  description = "RDS database endpoint (e.g., backend-db.xxxxx.us-east-1.rds.amazonaws.com)"
  sensitive   = true
}

variable "db_name" {
  type        = string
  description = "Database name"
  default     = "backend_production"
}

variable "db_user" {
  type        = string
  description = "Database username"
  sensitive   = true
}

variable "db_password" {
  type        = string
  description = "Database password"
  sensitive   = true
}

variable "jwt_secret" {
  type        = string
  description = "JWT secret for authentication"
  sensitive   = true
}

# ============================================================================
# Health Check Configuration
# ============================================================================

variable "health_check_path" {
  type        = string
  description = "Health check endpoint path"
  default     = "/health"
}

variable "health_check_interval" {
  type        = number
  description = "Health check interval in seconds"
  default     = 15
}

variable "health_check_timeout" {
  type        = number
  description = "Health check timeout in seconds"
  default     = 5
}

variable "healthy_threshold" {
  type        = number
  description = "Number of consecutive successful health checks required"
  default     = 2
}

variable "unhealthy_threshold" {
  type        = number
  description = "Number of consecutive failed health checks required"
  default     = 2
}

# ============================================================================
# ALB Configuration
# ============================================================================

variable "alb_arn" {
  type        = string
  description = "ARN of the existing Application Load Balancer"
}

variable "alb_listener_arn" {
  type        = string
  description = "ARN of the existing ALB listener (HTTP:80 or HTTPS:443)"
}

variable "ecs_target_group_arn" {
  type        = string
  description = "ARN of the existing ECS target group"
}

variable "eks_target_group_name" {
  type        = string
  description = "Name for the new EKS target group"
  default     = "eks-backend-tg"
}

# ============================================================================
# Traffic Routing Configuration
# ============================================================================

variable "eks_weight" {
  type        = number
  description = "Traffic weight for EKS target group (0-100). Start with 0 for safe deployment."
  default     = 0
  
  validation {
    condition     = var.eks_weight >= 0 && var.eks_weight <= 100
    error_message = "EKS weight must be between 0 and 100"
  }
}

variable "ecs_weight" {
  type        = number
  description = "Traffic weight for ECS target group (0-100). Start with 100 to maintain current traffic."
  default     = 100
  
  validation {
    condition     = var.ecs_weight >= 0 && var.ecs_weight <= 100
    error_message = "ECS weight must be between 0 and 100"
  }
}

# ============================================================================
# Optional Features
# ============================================================================

variable "enable_hpa" {
  type        = bool
  description = "Enable HorizontalPodAutoscaler for automatic scaling"
  default     = false
}
