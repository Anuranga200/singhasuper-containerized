# EKS Cluster IAM Role
# This IAM role allows the EKS service to manage cluster resources
# Requirements: 2.3, 7.2

resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-cluster-role"
      Environment = "exploration"
      ManagedBy   = "terraform"
    }
  )
}

# Attach AmazonEKSClusterPolicy - Required for EKS cluster operations
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# Attach AmazonEKSVPCResourceController - Required for VPC resource management
resource "aws_iam_role_policy_attachment" "vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

# EKS Cluster Resource
# This module creates an EKS cluster with configurable Kubernetes version,
# endpoint access, and CloudWatch logging for exploration purposes.
#
# Requirements: 1.1, 2.2, 10.1

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_public_access  = var.endpoint_public_access
    endpoint_private_access = var.endpoint_private_access
  }

  enabled_cluster_log_types = var.enabled_cluster_log_types

  tags = merge(
    var.tags,
    {
      Name        = var.cluster_name
      Environment = "exploration"
      ManagedBy   = "terraform"
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.vpc_resource_controller
  ]
}
