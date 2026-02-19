# Outputs for EKS Migration Root Module
# These outputs provide important information after deployment

# ============================================================================
# EKS Cluster Outputs
# ============================================================================

output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks_cluster.cluster_id
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint URL"
  value       = module.eks_cluster.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for cluster authentication"
  value       = module.eks_cluster.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks_cluster.cluster_security_group_id
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN used by the EKS cluster"
  value       = module.eks_cluster.cluster_iam_role_arn
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IAM Roles for Service Accounts (IRSA)"
  value       = module.eks_cluster.oidc_provider_arn
}

# ============================================================================
# EKS Node Group Outputs
# ============================================================================

output "node_group_id" {
  description = "EKS node group ID"
  value       = module.eks_node_group.node_group_id
}

output "node_group_arn" {
  description = "EKS node group ARN"
  value       = module.eks_node_group.node_group_arn
}

output "node_group_status" {
  description = "Current status of the node group"
  value       = module.eks_node_group.node_group_status
}

output "node_security_group_id" {
  description = "Security group ID for worker nodes"
  value       = module.eks_node_group.node_security_group_id
}

output "node_iam_role_arn" {
  description = "IAM role ARN used by worker nodes"
  value       = module.eks_node_group.node_iam_role_arn
}

# ============================================================================
# Kubernetes Resources Outputs
# ============================================================================

output "kubernetes_namespace" {
  description = "Kubernetes namespace where application is deployed"
  value       = module.kubernetes_resources.namespace
}

output "deployment_name" {
  description = "Name of the Kubernetes deployment"
  value       = module.kubernetes_resources.deployment_name
}

output "service_name" {
  description = "Name of the Kubernetes service"
  value       = module.kubernetes_resources.service_name
}

output "ingress_name" {
  description = "Name of the Kubernetes ingress"
  value       = module.kubernetes_resources.ingress_name
}

# ============================================================================
# ALB Integration Outputs
# ============================================================================

output "eks_target_group_arn" {
  description = "ARN of the EKS target group"
  value       = module.alb_integration.eks_target_group_arn
}

output "eks_target_group_name" {
  description = "Name of the EKS target group"
  value       = module.alb_integration.eks_target_group_name
}

output "listener_rule_arn" {
  description = "ARN of the ALB listener rule for weighted routing"
  value       = module.alb_integration.listener_rule_arn
}

# ============================================================================
# kubectl Configuration Command
# ============================================================================

output "kubectl_config_command" {
  description = "Command to configure kubectl for this cluster"
  value       = "aws eks update-kubeconfig --name ${module.eks_cluster.cluster_id} --region ${var.aws_region}"
}

# ============================================================================
# Verification Commands
# ============================================================================

output "verification_commands" {
  description = "Useful commands for verifying the deployment"
  value = {
    check_nodes        = "kubectl get nodes"
    check_pods         = "kubectl get pods -n ${var.namespace}"
    check_services     = "kubectl get svc -n ${var.namespace}"
    check_ingress      = "kubectl get ingress -n ${var.namespace}"
    describe_pods      = "kubectl describe pods -n ${var.namespace}"
    view_logs          = "kubectl logs -n ${var.namespace} -l app=${var.app_name} --tail=100"
    check_target_health = "aws elbv2 describe-target-health --target-group-arn ${module.alb_integration.eks_target_group_arn}"
  }
}

# ============================================================================
# Traffic Routing Status
# ============================================================================

output "traffic_routing" {
  description = "Current traffic routing configuration"
  value = {
    eks_weight = var.eks_weight
    ecs_weight = var.ecs_weight
    status     = var.eks_weight == 0 ? "All traffic to ECS (safe to destroy EKS)" : var.eks_weight == 100 ? "All traffic to EKS" : "Split traffic between ECS and EKS"
  }
}

# ============================================================================
# Cost Estimation
# ============================================================================

output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown (USD)"
  value = {
    eks_control_plane = "$72.00 (not free tier eligible)"
    ec2_nodes         = "$${var.desired_size * 14.40} (2x t3.small, may be covered by free tier)"
    ebs_volumes       = "$${var.desired_size * var.disk_size * 0.10} (20GB per node)"
    data_transfer     = "~$5.00 (estimated)"
    total_estimate    = "~$${72 + (var.desired_size * 14.40) + (var.desired_size * var.disk_size * 0.10) + 5} per month"
    note              = "Actual costs may vary. Set up billing alerts!"
  }
}
