# CloudWatch Alarms for EKS Monitoring
# Creates alarms for critical metrics with SNS notifications
# Requirements: 10.6

# SNS Topic for Alarm Notifications
resource "aws_sns_topic" "eks_alarms" {
  name = "${var.cluster_name}-eks-alarms"

  tags = merge(
    var.tags,
    {
      Name        = "${var.cluster_name}-eks-alarms"
      Environment = "exploration"
      ManagedBy   = "terraform"
    }
  )
}

# SNS Topic Subscription (Email)
resource "aws_sns_topic_subscription" "eks_alarms_email" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.eks_alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# Alarm: Low Node Count
resource "aws_cloudwatch_metric_alarm" "low_node_count" {
  alarm_name          = "${var.cluster_name}-low-node-count"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "cluster_node_count"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = var.min_node_count
  alarm_description   = "Alert when node count falls below minimum"
  alarm_actions       = [aws_sns_topic.eks_alarms.arn]

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = var.tags
}

# Alarm: High CPU Utilization
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.cluster_name}-high-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alert when CPU utilization exceeds 80%"
  alarm_actions       = [aws_sns_topic.eks_alarms.arn]

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = var.tags
}

# Alarm: High Memory Utilization
resource "aws_cloudwatch_metric_alarm" "high_memory" {
  alarm_name          = "${var.cluster_name}-high-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "node_memory_utilization"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "Alert when memory utilization exceeds 85%"
  alarm_actions       = [aws_sns_topic.eks_alarms.arn]

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = var.tags
}

# Alarm: Unhealthy Target Group Hosts
resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  alarm_name          = "${var.cluster_name}-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "Alert when EKS target group has unhealthy hosts"
  alarm_actions       = [aws_sns_topic.eks_alarms.arn]

  dimensions = {
    TargetGroup  = var.eks_target_group_arn_suffix
    LoadBalancer = var.alb_arn_suffix
  }

  tags = var.tags
}

# Alarm: High 5XX Error Rate
resource "aws_cloudwatch_metric_alarm" "high_5xx_errors" {
  alarm_name          = "${var.cluster_name}-high-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Alert when 5XX errors exceed threshold"
  alarm_actions       = [aws_sns_topic.eks_alarms.arn]

  dimensions = {
    TargetGroup  = var.eks_target_group_arn_suffix
    LoadBalancer = var.alb_arn_suffix
  }

  tags = var.tags
}
