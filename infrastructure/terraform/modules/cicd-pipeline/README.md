# CI/CD Pipeline Terraform Module

This module creates a complete CI/CD pipeline for automated deployment of the Singha Loyalty System.

## Features

- ✅ **Automated Builds**: CodeBuild compiles Docker images on every push
- ✅ **Automated Deployments**: CodePipeline deploys to ECS with zero downtime
- ✅ **GitHub Integration**: Webhooks automatically trigger on git push
- ✅ **Secure**: IAM roles follow least-privilege principle
- ✅ **Cost-Optimized**: Build caching and efficient resource usage
- ✅ **Monitored**: CloudWatch logs for all build and deploy activities

## Architecture

```
GitHub → CodePipeline → CodeBuild → ECR → ECS
   ↓          ↓            ↓         ↓      ↓
Webhook   Orchestrate   Build    Store  Deploy
          3 Stages      Image    Image  Rolling
```

## Resources Created

### Core Pipeline Resources
- **CodePipeline**: 3-stage pipeline (Source → Build → Deploy)
- **CodeBuild Project**: Builds Docker images
- **S3 Bucket**: Stores pipeline artifacts
- **CloudWatch Log Group**: Stores build logs

### IAM Resources
- **CodeBuild Role**: Permissions for building and pushing images
- **CodePipeline Role**: Permissions for orchestrating deployments

### Security
- **S3 Encryption**: AES-256 encryption for artifacts
- **S3 Public Access Block**: Prevents public access
- **Least Privilege IAM**: Minimal required permissions

## Usage

```hcl
module "cicd_pipeline" {
  source = "./modules/cicd-pipeline"

  project_name = "singha-loyalty"
  environment  = "production"
  aws_region   = "us-east-1"

  # GitHub Configuration
  github_connection_arn = "arn:aws:codestar-connections:us-east-1:123456789012:connection/xxxxx"
  github_repository     = "username/repo"
  github_branch         = "main"

  # ECR Configuration
  ecr_repository_name = "singha-loyalty"

  # ECS Configuration
  ecs_cluster_name = "singha-loyalty-cluster"
  ecs_service_name = "singha-loyalty-service"

  # Optional: CodeBuild Configuration
  codebuild_compute_type = "BUILD_GENERAL1_SMALL"
  codebuild_image        = "aws/codebuild/standard:7.0"
  buildspec_path         = "infrastructure/buildspec.yml"

  # Optional: Monitoring
  log_retention_days = 7
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_name | Project name for resource naming | string | - | yes |
| environment | Environment name | string | - | yes |
| aws_region | AWS region | string | - | yes |
| github_connection_arn | CodeStar connection ARN | string | - | yes |
| github_repository | GitHub repo (owner/repo) | string | - | yes |
| github_branch | Branch to monitor | string | "main" | no |
| ecr_repository_name | ECR repository name | string | - | yes |
| ecs_cluster_name | ECS cluster name | string | - | yes |
| ecs_service_name | ECS service name | string | - | yes |
| codebuild_compute_type | Build compute type | string | "BUILD_GENERAL1_SMALL" | no |
| codebuild_image | CodeBuild Docker image | string | "aws/codebuild/standard:7.0" | no |
| buildspec_path | Path to buildspec file | string | "infrastructure/buildspec.yml" | no |
| log_retention_days | Log retention in days | number | 7 | no |

## Outputs

| Name | Description |
|------|-------------|
| pipeline_name | Name of the CodePipeline |
| pipeline_arn | ARN of the CodePipeline |
| codebuild_project_name | Name of the CodeBuild project |
| codebuild_project_arn | ARN of the CodeBuild project |
| artifacts_bucket_name | S3 bucket for artifacts |
| artifacts_bucket_arn | ARN of the S3 bucket |
| codebuild_role_arn | ARN of CodeBuild IAM role |
| codepipeline_role_arn | ARN of CodePipeline IAM role |
| codebuild_log_group_name | CloudWatch log group name |

## Pipeline Stages

### 1. Source Stage
- **Provider**: GitHub (via CodeStar Connection)
- **Action**: Pulls latest code from specified branch
- **Output**: Source code artifact
- **Duration**: ~30 seconds

### 2. Build Stage
- **Provider**: CodeBuild
- **Actions**:
  1. Login to ECR
  2. Build Docker image
  3. Tag image with commit hash
  4. Push to ECR
  5. Create imagedefinitions.json
- **Output**: Build artifact with image definitions
- **Duration**: 3-5 minutes

### 3. Deploy Stage
- **Provider**: ECS
- **Actions**:
  1. Update task definition with new image
  2. Update ECS service
  3. Perform rolling deployment
  4. Health checks
- **Output**: Updated ECS service
- **Duration**: 5-10 minutes

## Build Process

The build process is defined in `buildspec.yml`:

```yaml
phases:
  pre_build:
    - Login to ECR
    - Set image tags
  
  build:
    - Build Docker image
    - Tag image
  
  post_build:
    - Push to ECR
    - Create imagedefinitions.json

artifacts:
  - imagedefinitions.json
```

## Deployment Strategy

- **Type**: Rolling deployment
- **Minimum healthy percent**: 100%
- **Maximum percent**: 200%
- **Health checks**: ALB target group health checks
- **Rollback**: Automatic on deployment failure

## Cost Breakdown

### Monthly Costs (50 builds/month)

| Service | Usage | Cost |
|---------|-------|------|
| CodePipeline | 1 active pipeline | $1.00 |
| CodeBuild | 50 builds × 5 min × SMALL | $1.25 |
| S3 | 5GB storage | $0.12 |
| CloudWatch Logs | 1GB logs | $0.50 |
| **Total** | | **$2.87/month** |

### Per-Build Cost
- **SMALL**: $0.005/minute = $0.025/build (5 min)
- **MEDIUM**: $0.01/minute = $0.05/build (5 min)
- **LARGE**: $0.02/minute = $0.10/build (5 min)

## Security Considerations

### IAM Permissions
- CodeBuild can only:
  - Write to CloudWatch Logs
  - Read/write to artifacts bucket
  - Push to ECR
- CodePipeline can only:
  - Read/write to artifacts bucket
  - Start CodeBuild builds
  - Update specific ECS service

### Secrets Management
- Database passwords: Use AWS Secrets Manager
- JWT secrets: Use AWS Secrets Manager
- GitHub token: Managed by CodeStar Connection

### Network Security
- CodeBuild runs in AWS-managed VPC
- No direct access to private resources
- ECR uses VPC endpoints (optional)

## Monitoring

### CloudWatch Logs
- **Build logs**: `/aws/codebuild/singha-loyalty-build`
- **Retention**: Configurable (default 7 days)

### CloudWatch Metrics
- Build success/failure rate
- Build duration
- Pipeline execution time

### Alarms (Optional)
```hcl
resource "aws_cloudwatch_metric_alarm" "build_failures" {
  alarm_name          = "codebuild-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FailedBuilds"
  namespace           = "AWS/CodeBuild"
  period              = "300"
  statistic           = "Sum"
  threshold           = "2"
}
```

## Troubleshooting

### Build Fails
1. Check CloudWatch logs: `/aws/codebuild/singha-loyalty-build`
2. Verify buildspec.yml syntax
3. Test Docker build locally
4. Check ECR permissions

### Deploy Fails
1. Check ECS service events
2. Verify imagedefinitions.json format
3. Check task definition is valid
4. Verify IAM role permissions

### Pipeline Not Triggering
1. Check GitHub connection status
2. Verify webhook exists in GitHub
3. Check branch name matches
4. Review CloudTrail logs

## Best Practices

### 1. Use Build Caching
Already enabled in buildspec.yml:
```yaml
cache:
  paths:
    - '/root/.npm/**/*'
    - 'server/node_modules/**/*'
```

### 2. Tag Images Properly
Images are tagged with:
- `latest`: Most recent build
- `<commit-hash>`: Specific commit

### 3. Monitor Build Times
- Set up CloudWatch alarms for long builds
- Optimize Dockerfile for faster builds
- Use multi-stage builds

### 4. Secure Artifacts
- Enable S3 versioning (already enabled)
- Enable S3 encryption (already enabled)
- Set lifecycle policies for old artifacts

### 5. Test Locally First
```bash
# Test build locally before pushing
cd server
docker build -t test .
docker run -p 3000:3000 test
```

## Advanced Configuration

### Add Manual Approval
```hcl
# Add between Build and Deploy stages
stage {
  name = "Approval"
  action {
    name     = "ManualApproval"
    category = "Approval"
    owner    = "AWS"
    provider = "Manual"
    version  = "1"
  }
}
```

### Add Testing Stage
```hcl
stage {
  name = "Test"
  action {
    name             = "Test"
    category         = "Test"
    owner            = "AWS"
    provider         = "CodeBuild"
    version          = "1"
    input_artifacts  = ["source_output"]
    configuration = {
      ProjectName = aws_codebuild_project.test.name
    }
  }
}
```

### Multi-Environment Deployment
```hcl
# Deploy to dev, then staging, then production
stage {
  name = "Deploy-Dev"
  # ... deploy to dev ECS service
}

stage {
  name = "Approval-Staging"
  # ... manual approval
}

stage {
  name = "Deploy-Staging"
  # ... deploy to staging ECS service
}
```

## Examples

### Basic Setup
```hcl
module "cicd_pipeline" {
  source = "./modules/cicd-pipeline"

  project_name          = "my-app"
  environment           = "production"
  aws_region            = "us-east-1"
  github_connection_arn = "arn:aws:codestar-connections:..."
  github_repository     = "user/repo"
  github_branch         = "main"
  ecr_repository_name   = "my-app"
  ecs_cluster_name      = "my-cluster"
  ecs_service_name      = "my-service"
}
```

### With Custom Build Settings
```hcl
module "cicd_pipeline" {
  source = "./modules/cicd-pipeline"

  # ... basic settings ...

  codebuild_compute_type = "BUILD_GENERAL1_MEDIUM"
  codebuild_image        = "aws/codebuild/standard:7.0"
  buildspec_path         = "custom/buildspec.yml"
  log_retention_days     = 14
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 5.0 |

## License

This module is part of the Singha Loyalty System project.

## Authors

Created for the Singha Loyalty System deployment automation.

## Support

For issues or questions:
1. Check CloudWatch logs
2. Review AWS CodePipeline documentation
3. Check GitHub connection status
4. Review IAM permissions
