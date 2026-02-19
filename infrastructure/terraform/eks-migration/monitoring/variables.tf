# Variables for Monitoring Module

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "log_retention_days" {
  type        = number
  description = "Number of days to retain logs in CloudWatch"
  default     = 7
}

variable "alarm_email" {
  type        = string
  description = "Email address for alarm notifications"
  default     = ""
}

variable "min_node_count" {
  type        = number
  description = "Minimum acceptable node count for alarm"
  default     = 2
}

variable "eks_target_group_arn_suffix" {
  type        = string
  description = "ARN suffix of EKS target group for alarms"
  default     = ""
}

variable "alb_arn_suffix" {
  type        = string
  description = "ARN suffix of ALB for alarms"
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}
