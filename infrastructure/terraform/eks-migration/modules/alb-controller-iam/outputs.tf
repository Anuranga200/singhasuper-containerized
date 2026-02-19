# Outputs for ALB Controller IAM Module

output "role_arn" {
  value       = aws_iam_role.alb_controller.arn
  description = "ARN of the IAM role for AWS Load Balancer Controller"
}

output "role_name" {
  value       = aws_iam_role.alb_controller.name
  description = "Name of the IAM role for AWS Load Balancer Controller"
}

output "policy_arn" {
  value       = aws_iam_policy.alb_controller.arn
  description = "ARN of the IAM policy for AWS Load Balancer Controller"
}
