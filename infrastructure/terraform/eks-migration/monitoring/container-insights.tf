# CloudWatch Container Insights Configuration
# Enables comprehensive monitoring for EKS cluster
# Requirements: 10.1, 10.5

# CloudWatch Log Group for Container Insights
resource "aws_cloudwatch_log_group" "container_insights" {
  name              = "/aws/containerinsights/${var.cluster_name}/performance"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-container-insights"
      Environment = "exploration"
      ManagedBy   = "terraform"
    }
  )
}

# CloudWatch Log Group for Application Logs
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/eks/${var.cluster_name}/application"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-application-logs"
      Environment = "exploration"
      ManagedBy   = "terraform"
    }
  )
}

# CloudWatch Log Group for Data Plane Logs
resource "aws_cloudwatch_log_group" "dataplane" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-dataplane-logs"
      Environment = "exploration"
      ManagedBy   = "terraform"
    }
  )
}

# Note: Container Insights is enabled at the cluster level via EKS cluster configuration
# The CloudWatch agent and Fluent Bit are deployed as DaemonSets (see fluent-bit.yaml)
