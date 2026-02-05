# ============================================
# VARIABLES - Input Parameters
# ============================================
# Following AWS Well-Architected Framework:
# - Security: Sensitive data marked as sensitive
# - Cost Optimization: Configurable instance sizes
# - Reliability: Multi-AZ and backup configurations
# - Performance: Adjustable compute resources

# ==================== General ====================
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "singha-loyalty"
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "production"
  
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

# ==================== Networking ====================
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

# ==================== Database ====================
variable "db_username" {
  description = "Master username for RDS MySQL database"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "db_password" {
  description = "Master password for RDS MySQL database (min 8 characters)"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.db_password) >= 8
    error_message = "Database password must be at least 8 characters long."
  }
}

variable "db_instance_class" {
  description = "RDS instance class (e.g., db.t3.micro, db.t3.small)"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
  default     = 20
  
  validation {
    condition     = var.allocated_storage >= 20 && var.allocated_storage <= 65536
    error_message = "Allocated storage must be between 20 and 65536 GB."
  }
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment for RDS (recommended for production)"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups (0-35)"
  type        = number
  default     = 7
  
  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "Backup retention period must be between 0 and 35 days."
  }
}

# ==================== Application ====================
variable "jwt_secret" {
  description = "JWT secret key for authentication"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.jwt_secret) >= 32
    error_message = "JWT secret must be at least 32 characters long."
  }
}

variable "cors_origin" {
  description = "CORS origin for API requests"
  type        = string
  default     = "*"
}

# ==================== Container ====================
variable "container_image" {
  description = "Docker image URI for ECS task (will use ECR repository if not provided)"
  type        = string
  default     = ""
}

variable "container_cpu" {
  description = "CPU units for ECS task (256 = 0.25 vCPU)"
  type        = number
  default     = 256
  
  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.container_cpu)
    error_message = "CPU must be one of: 256, 512, 1024, 2048, 4096."
  }
}

variable "container_memory" {
  description = "Memory for ECS task in MB"
  type        = number
  default     = 512
  
  validation {
    condition     = var.container_memory >= 512 && var.container_memory <= 30720
    error_message = "Memory must be between 512 and 30720 MB."
  }
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
  
  validation {
    condition     = var.desired_count >= 1 && var.desired_count <= 10
    error_message = "Desired count must be between 1 and 10."
  }
}

# ==================== Auto Scaling ====================
variable "enable_autoscaling" {
  description = "Enable auto scaling for ECS service"
  type        = bool
  default     = true
}

variable "min_capacity" {
  description = "Minimum number of ECS tasks"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Maximum number of ECS tasks"
  type        = number
  default     = 10
}

variable "cpu_target_value" {
  description = "Target CPU utilization percentage for auto scaling"
  type        = number
  default     = 70
}

variable "memory_target_value" {
  description = "Target memory utilization percentage for auto scaling"
  type        = number
  default     = 80
}

# ==================== Monitoring ====================
variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for ECS"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
  
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention must be a valid CloudWatch Logs retention period."
  }
}

# ==================== Cost Optimization ====================
variable "use_spot_instances" {
  description = "Use Fargate Spot for cost savings (recommended for non-critical workloads)"
  type        = bool
  default     = true
}

variable "spot_weight" {
  description = "Weight for Fargate Spot capacity provider (0-100)"
  type        = number
  default     = 80
  
  validation {
    condition     = var.spot_weight >= 0 && var.spot_weight <= 100
    error_message = "Spot weight must be between 0 and 100."
  }
}

# ==================== Frontend ====================
variable "enable_cloudfront" {
  description = "Enable CloudFront distribution for frontend"
  type        = bool
  default     = true
}

variable "cloudfront_price_class" {
  description = "CloudFront price class (PriceClass_All, PriceClass_200, PriceClass_100)"
  type        = string
  default     = "PriceClass_100"
  
  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.cloudfront_price_class)
    error_message = "Price class must be PriceClass_All, PriceClass_200, or PriceClass_100."
  }
}

# ==================== Tags ====================
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
