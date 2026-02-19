# Variables for ALB Controller IAM Module

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the OIDC provider for the EKS cluster"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}
