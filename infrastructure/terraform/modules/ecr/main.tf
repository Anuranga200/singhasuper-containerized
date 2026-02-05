# ============================================
# ECR MODULE - Container Registry
# ============================================
# Well-Architected Framework:
# - Security: Image scanning, encryption at rest
# - Cost Optimization: Lifecycle policies to remove old images
# - Operational Excellence: Immutable tags

resource "aws_ecr_repository" "main" {
  name                 = "${var.project_name}-backend"
  image_tag_mutability = "MUTABLE"  # Set to IMMUTABLE for production

  image_scanning_configuration {
    scan_on_push = true  # Automatic vulnerability scanning
  }

  encryption_configuration {
    encryption_type = "AES256"  # Use KMS for enhanced security
  }

  tags = {
    Name = "${var.project_name}-backend-repo"
  }
}

# Lifecycle policy to clean up old images
resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Remove untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Repository policy for cross-account access (if needed)
resource "aws_ecr_repository_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPushPull"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}
