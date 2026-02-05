# ============================================
# OUTPUTS - Resource Information
# ============================================
# Following best practices:
# - Expose only necessary information
# - Mark sensitive outputs appropriately
# - Provide useful deployment information

# ==================== VPC Outputs ====================
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.vpc.private_subnet_ids
}

# ==================== Database Outputs ====================
output "rds_endpoint" {
  description = "RDS MySQL endpoint address"
  value       = module.rds.db_endpoint
}

output "rds_port" {
  description = "RDS MySQL port"
  value       = module.rds.db_port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = module.rds.db_name
}

output "rds_instance_id" {
  description = "RDS instance identifier"
  value       = module.rds.db_instance_id
}

# ==================== ECR Outputs ====================
output "ecr_repository_url" {
  description = "ECR repository URL for pushing Docker images"
  value       = module.ecr.repository_url
}

output "ecr_repository_arn" {
  description = "ECR repository ARN"
  value       = module.ecr.repository_arn
}

# ==================== Load Balancer Outputs ====================
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.alb.alb_zone_id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.alb_arn
}

output "api_endpoint" {
  description = "API endpoint URL (use this to access your backend)"
  value       = "http://${module.alb.alb_dns_name}"
}

# ==================== ECS Outputs ====================
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs.cluster_arn
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.ecs.service_name
}

output "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = module.ecs.task_definition_arn
}

# ==================== Frontend Outputs ====================
output "frontend_bucket_name" {
  description = "S3 bucket name for frontend hosting"
  value       = module.s3_frontend.bucket_name
}

output "frontend_bucket_arn" {
  description = "S3 bucket ARN for frontend"
  value       = module.s3_frontend.bucket_arn
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.cloudfront.distribution_id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = module.cloudfront.distribution_domain_name
}

output "frontend_url" {
  description = "Frontend URL (use this to access your application)"
  value       = "https://${module.cloudfront.distribution_domain_name}"
}

# ==================== Security Group Outputs ====================
output "alb_security_group_id" {
  description = "Security group ID for ALB"
  value       = module.security_groups.alb_security_group_id
}

output "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
  value       = module.security_groups.ecs_security_group_id
}

output "rds_security_group_id" {
  description = "Security group ID for RDS"
  value       = module.security_groups.rds_security_group_id
}

# ==================== Deployment Information ====================
output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    project_name = var.project_name
    environment  = var.environment
    region       = var.aws_region
    api_endpoint = "http://${module.alb.alb_dns_name}"
    frontend_url = "https://${module.cloudfront.distribution_domain_name}"
    ecr_repo     = module.ecr.repository_url
  }
}

# ==================== Next Steps ====================
output "next_steps" {
  description = "Instructions for next steps after deployment"
  value = <<-EOT
    
    ✅ Infrastructure deployed successfully!
    
    📋 Next Steps:
    
    1. Build and push your Docker image:
       docker build -t ${module.ecr.repository_url}:latest ./server
       aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${module.ecr.repository_url}
       docker push ${module.ecr.repository_url}:latest
    
    2. Update ECS service to use the new image:
       aws ecs update-service --cluster ${module.ecs.cluster_name} --service ${module.ecs.service_name} --force-new-deployment --region ${var.aws_region}
    
    3. Run database migrations:
       Connect to RDS endpoint: ${module.rds.db_endpoint}
       Database name: ${module.rds.db_name}
    
    4. Deploy frontend to S3:
       npm run build
       aws s3 sync ./dist s3://${module.s3_frontend.bucket_name}/ --delete
       aws cloudfront create-invalidation --distribution-id ${module.cloudfront.distribution_id} --paths "/*"
    
    5. Access your application:
       Backend API: http://${module.alb.alb_dns_name}
       Frontend: https://${module.cloudfront.distribution_domain_name}
    
    📊 Monitoring:
       - CloudWatch Logs: /ecs/${var.project_name}
       - ECS Console: https://console.aws.amazon.com/ecs/home?region=${var.aws_region}#/clusters/${module.ecs.cluster_name}
       - RDS Console: https://console.aws.amazon.com/rds/home?region=${var.aws_region}
  EOT
}
