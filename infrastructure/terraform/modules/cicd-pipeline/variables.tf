# ============================================
# CI/CD Pipeline Module - Variables
# ============================================

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

# ==================== GitHub Configuration ====================
variable "github_connection_arn" {
  description = "ARN of the CodeStar connection to GitHub"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository in format 'owner/repo'"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch to monitor"
  type        = string
  default     = "main"
}

# ==================== ECR Configuration ====================
variable "ecr_repository_name" {
  description = "Name of the ECR repository"
  type        = string
}

# ==================== ECS Configuration ====================
variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "ecs_service_name" {
  description = "Name of the ECS service"
  type        = string
}

# ==================== CodeBuild Configuration ====================
variable "codebuild_compute_type" {
  description = "CodeBuild compute type"
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
  
  validation {
    condition     = contains(["BUILD_GENERAL1_SMALL", "BUILD_GENERAL1_MEDIUM", "BUILD_GENERAL1_LARGE"], var.codebuild_compute_type)
    error_message = "Compute type must be BUILD_GENERAL1_SMALL, BUILD_GENERAL1_MEDIUM, or BUILD_GENERAL1_LARGE."
  }
}

variable "codebuild_image" {
  description = "CodeBuild Docker image"
  type        = string
  default     = "aws/codebuild/standard:7.0"
}

variable "buildspec_path" {
  description = "Path to buildspec file in repository"
  type        = string
  default     = "infrastructure/buildspec.yml"
}

# ==================== Monitoring ====================
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}
