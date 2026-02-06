# 🚀 Quick Reference Guide

## Essential Commands

### Initial Setup
```powershell
# Navigate to terraform directory
cd infrastructure/terraform

# Copy configuration template
copy terraform.tfvars.example terraform.tfvars

# Edit configuration (update passwords and secrets!)
notepad terraform.tfvars

# Initialize Terraform
terraform init
```

### Deployment
```powershell
# Preview changes
terraform plan

# Deploy infrastructure
terraform apply

# Deploy without confirmation (use with caution!)
terraform apply -auto-approve

# Deploy specific module
terraform apply -target=module.ecs
```

### Information
```powershell
# Show all outputs
terraform output

# Show specific output
terraform output ecr_repository_url
terraform output api_endpoint
terraform output frontend_url

# Show current state
terraform show

# List all resources
terraform state list
```

### Updates
```powershell
# Update specific resource
terraform apply -target=module.ecs.aws_ecs_service.main

# Refresh state
terraform refresh

# Force resource recreation
terraform taint module.ecs.aws_ecs_service.main
terraform apply
```

### Cleanup
```powershell
# Preview destruction
terraform plan -destroy

# Destroy all resources
terraform destroy

# Destroy specific resource
terraform destroy -target=module.ecs
```

---

## Common Tasks

### 1. Deploy New Docker Image

```powershell
# Build and push image
$ECR_REPO = terraform output -raw ecr_repository_url
docker build -t ${ECR_REPO}:latest ./server
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REPO
docker push ${ECR_REPO}:latest

# Update ECS service
$CLUSTER = terraform output -raw ecs_cluster_name
$SERVICE = terraform output -raw ecs_service_name
aws ecs update-service --cluster $CLUSTER --service $SERVICE --force-new-deployment
```

### 2. Scale ECS Tasks

```powershell
# Edit terraform.tfvars
desired_count = 5

# Apply changes
terraform apply -target=module.ecs
```

### 3. Update Environment Variables

```powershell
# Edit terraform.tfvars
cors_origin = "https://yourdomain.com"

# Apply changes
terraform apply -target=module.ecs
```

### 4. Deploy Frontend

```powershell
# Build frontend
npm run build

# Upload to S3
$BUCKET = terraform output -raw frontend_bucket_name
aws s3 sync ./dist s3://${BUCKET}/ --delete

# Invalidate CloudFront cache
$DISTRIBUTION = terraform output -raw cloudfront_distribution_id
aws cloudfront create-invalidation --distribution-id $DISTRIBUTION --paths "/*"
```

### 5. View Logs

```powershell
# ECS logs
aws logs tail /ecs/singha-loyalty --follow

# RDS logs
aws rds describe-db-log-files --db-instance-identifier singha-loyalty-db
```

### 6. Connect to Database

```powershell
# Get connection info
$DB_ENDPOINT = terraform output -raw rds_endpoint
$DB_NAME = terraform output -raw rds_database_name

# Connect
mysql -h $DB_ENDPOINT -u admin -p $DB_NAME
```

---

## Troubleshooting

### Issue: Terraform Init Fails
```powershell
Remove-Item -Recurse -Force .terraform
terraform init
```

### Issue: State Lock
```powershell
# Force unlock (use with caution!)
terraform force-unlock LOCK_ID
```

### Issue: Resource Already Exists
```powershell
# Import existing resource
terraform import module.vpc.aws_vpc.main vpc-xxxxx
```

### Issue: ECS Tasks Not Starting
```powershell
# Check service events
aws ecs describe-services --cluster $CLUSTER --services $SERVICE

# Check task logs
aws logs tail /ecs/singha-loyalty --follow
```

### Issue: Cannot Access API
```powershell
# Check target health
$TG_ARN = terraform output -raw target_group_arn
aws elbv2 describe-target-health --target-group-arn $TG_ARN

# Check security groups
terraform show | Select-String "security_group"
```

---

## Important Outputs

```powershell
# API Endpoint
terraform output api_endpoint
# Use: http://singha-loyalty-alb-xxxxx.us-east-1.elb.amazonaws.com

# Frontend URL
terraform output frontend_url
# Use: https://xxxxx.cloudfront.net

# ECR Repository
terraform output ecr_repository_url
# Use: xxxxx.dkr.ecr.us-east-1.amazonaws.com/singha-loyalty-backend

# Database Endpoint
terraform output rds_endpoint
# Use: singha-loyalty-db.xxxxx.us-east-1.rds.amazonaws.com

# ECS Cluster
terraform output ecs_cluster_name
# Use: singha-loyalty-cluster

# S3 Bucket
terraform output frontend_bucket_name
# Use: singha-loyalty-frontend-production
```

---

## Cost Management

### Check Current Costs
```powershell
# View cost by service (last 30 days)
aws ce get-cost-and-usage `
    --time-period Start=2026-01-01,End=2026-02-01 `
    --granularity MONTHLY `
    --metrics BlendedCost `
    --group-by Type=DIMENSION,Key=SERVICE
```

### Reduce Costs
```powershell
# Scale down to 1 task
desired_count = 1

# Use smaller RDS instance
db_instance_class = "db.t3.micro"

# Disable Container Insights
enable_container_insights = false

# Apply changes
terraform apply
```

---

## Security

### Rotate Secrets
```powershell
# Generate new JWT secret
-join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})

# Update terraform.tfvars
jwt_secret = "NEW_SECRET"

# Apply changes
terraform apply -target=module.ecs
```

### Update Database Password
```powershell
# Update terraform.tfvars
db_password = "NEW_PASSWORD"

# Apply changes (will cause downtime!)
terraform apply -target=module.rds
```

### Review Security Groups
```powershell
# List security groups
terraform state list | Select-String "security_group"

# Show security group details
terraform state show module.security_groups.aws_security_group.ecs
```

---

## Monitoring

### CloudWatch Dashboards
```
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:
```

### ECS Console
```
https://console.aws.amazon.com/ecs/home?region=us-east-1#/clusters/singha-loyalty-cluster
```

### RDS Console
```
https://console.aws.amazon.com/rds/home?region=us-east-1
```

### Cost Explorer
```
https://console.aws.amazon.com/cost-management/home?region=us-east-1#/dashboard
```

---

## Backup & Recovery

### Create RDS Snapshot
```powershell
aws rds create-db-snapshot `
    --db-instance-identifier singha-loyalty-db `
    --db-snapshot-identifier singha-loyalty-manual-snapshot-$(Get-Date -Format "yyyy-MM-dd-HHmm")
```

### Restore from Snapshot
```powershell
# List snapshots
aws rds describe-db-snapshots --db-instance-identifier singha-loyalty-db

# Restore (requires Terraform import after)
aws rds restore-db-instance-from-db-snapshot `
    --db-instance-identifier singha-loyalty-db-restored `
    --db-snapshot-identifier snapshot-name
```

### Export Terraform State
```powershell
# Backup state file
terraform state pull > terraform.tfstate.backup

# Store securely (encrypted S3, etc.)
```

---

## Environment Management

### Development Environment
```hcl
# dev.tfvars
environment = "development"
db_instance_class = "db.t3.micro"
multi_az = false
desired_count = 1
use_spot_instances = true
spot_weight = 100
enable_container_insights = false
```

```powershell
terraform apply -var-file="dev.tfvars"
```

### Production Environment
```hcl
# prod.tfvars
environment = "production"
db_instance_class = "db.t3.small"
multi_az = true
desired_count = 3
use_spot_instances = true
spot_weight = 50
enable_container_insights = true
```

```powershell
terraform apply -var-file="prod.tfvars"
```

---

## Useful AWS CLI Commands

### ECS
```powershell
# List tasks
aws ecs list-tasks --cluster $CLUSTER

# Describe task
aws ecs describe-tasks --cluster $CLUSTER --tasks TASK_ARN

# Stop task
aws ecs stop-task --cluster $CLUSTER --task TASK_ARN

# Update service
aws ecs update-service --cluster $CLUSTER --service $SERVICE --desired-count 3
```

### RDS
```powershell
# Describe instance
aws rds describe-db-instances --db-instance-identifier singha-loyalty-db

# Reboot instance
aws rds reboot-db-instance --db-instance-identifier singha-loyalty-db

# Modify instance
aws rds modify-db-instance --db-instance-identifier singha-loyalty-db --db-instance-class db.t3.small
```

### CloudWatch
```powershell
# List log groups
aws logs describe-log-groups

# Tail logs
aws logs tail /ecs/singha-loyalty --follow --since 1h

# Get metrics
aws cloudwatch get-metric-statistics `
    --namespace AWS/ECS `
    --metric-name CPUUtilization `
    --dimensions Name=ServiceName,Value=singha-loyalty-service `
    --start-time 2026-02-03T00:00:00Z `
    --end-time 2026-02-03T23:59:59Z `
    --period 3600 `
    --statistics Average
```

---

## Best Practices

✅ **Always run `terraform plan` before `apply`**
✅ **Use version control for .tf files**
✅ **Never commit terraform.tfvars (contains secrets)**
✅ **Tag all resources appropriately**
✅ **Use remote state for team collaboration**
✅ **Enable MFA on AWS account**
✅ **Regular backups of RDS**
✅ **Monitor costs weekly**
✅ **Review security groups monthly**
✅ **Keep Terraform and providers updated**

---

## Emergency Procedures

### Complete Outage
```powershell
# 1. Check ECS service
aws ecs describe-services --cluster $CLUSTER --services $SERVICE

# 2. Check target health
aws elbv2 describe-target-health --target-group-arn $TG_ARN

# 3. Check RDS status
aws rds describe-db-instances --db-instance-identifier singha-loyalty-db

# 4. Force new deployment
aws ecs update-service --cluster $CLUSTER --service $SERVICE --force-new-deployment

# 5. Check logs
aws logs tail /ecs/singha-loyalty --follow
```

### Rollback Deployment
```powershell
# 1. List task definitions
aws ecs list-task-definitions --family-prefix singha-loyalty-task

# 2. Update service to previous version
aws ecs update-service `
    --cluster $CLUSTER `
    --service $SERVICE `
    --task-definition singha-loyalty-task:PREVIOUS_VERSION
```

### Database Recovery
```powershell
# 1. List snapshots
aws rds describe-db-snapshots --db-instance-identifier singha-loyalty-db

# 2. Restore from snapshot
aws rds restore-db-instance-from-db-snapshot `
    --db-instance-identifier singha-loyalty-db-restored `
    --db-snapshot-identifier SNAPSHOT_ID

# 3. Update Terraform to point to new instance
# 4. Run terraform apply
```

---

## Support Resources

- **Terraform Docs**: https://www.terraform.io/docs
- **AWS Provider Docs**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- **AWS CLI Docs**: https://docs.aws.amazon.com/cli/
- **Project README**: ./README.md
- **Deployment Guide**: ./DEPLOYMENT_GUIDE.md
- **Cost Estimation**: ./COST_ESTIMATION.md

---

**Last Updated**: February 2026
