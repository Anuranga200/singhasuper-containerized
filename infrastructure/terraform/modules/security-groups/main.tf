# ============================================
# SECURITY GROUPS MODULE
# ============================================
# Well-Architected Framework - Security Pillar:
# - Principle of least privilege
# - Defense in depth with layered security
# - Separate security groups for each tier

# ==================== ALB Security Group ====================
resource "aws_security_group" "alb" {
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# Allow HTTP from anywhere
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
  description = "Allow HTTP from anywhere"

  tags = {
    Name = "${var.project_name}-alb-http-ingress"
  }
}

# Allow HTTPS from anywhere
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  description = "Allow HTTPS from anywhere"

  tags = {
    Name = "${var.project_name}-alb-https-ingress"
  }
}

# Allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
  description = "Allow all outbound traffic"

  tags = {
    Name = "${var.project_name}-alb-egress"
  }
}

# ==================== ECS Security Group ====================
resource "aws_security_group" "ecs" {
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-ecs-sg"
  }
}

# Allow traffic from ALB on port 3000
resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id = aws_security_group.ecs.id
  
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
  description                  = "Allow traffic from ALB"

  tags = {
    Name = "${var.project_name}-ecs-from-alb-ingress"
  }
}

# Allow all outbound traffic (for database, ECR, etc.)
resource "aws_vpc_security_group_egress_rule" "ecs_all" {
  security_group_id = aws_security_group.ecs.id
  
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
  description = "Allow all outbound traffic"

  tags = {
    Name = "${var.project_name}-ecs-egress"
  }
}

# ==================== RDS Security Group ====================
resource "aws_security_group" "rds" {
  description = "Security group for RDS MySQL"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# Allow MySQL traffic from ECS tasks
resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs" {
  security_group_id = aws_security_group.rds.id
  
  referenced_security_group_id = aws_security_group.ecs.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  description                  = "Allow MySQL from ECS tasks"

  tags = {
    Name = "${var.project_name}-rds-from-ecs-ingress"
  }
}

# Allow outbound traffic (for maintenance, updates)
resource "aws_vpc_security_group_egress_rule" "rds_all" {
  security_group_id = aws_security_group.rds.id
  
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
  description = "Allow all outbound traffic"

  tags = {
    Name = "${var.project_name}-rds-egress"
  }
}
