# ✅ Deployment Checklist

Use this checklist to ensure a smooth deployment of your Singha Loyalty System infrastructure.

---

## Pre-Deployment Checklist

### Prerequisites Installation
- [ ] AWS CLI installed and working
  ```powershell
  aws --version
  ```
- [ ] Terraform installed (v1.0+)
  ```powershell
  terraform --version
  ```
- [ ] Docker installed
  ```powershell
  docker --version
  ```
- [ ] Git installed
  ```powershell
  git --version
  ```

### AWS Account Setup
- [ ] AWS account created
- [ ] IAM user created (not using root)
- [ ] MFA enabled on account
- [ ] AWS CLI configured
  ```powershell
  aws configure
  aws sts get-caller-identity
  ```
- [ ] Sufficient service quotas
  - [ ] VPCs (need 1)
  - [ ] Elastic IPs (need 0-2)
  - [ ] RDS instances (need 1)
  - [ ] ECS tasks (need 2-10)

### Documentation Review
- [ ] Read 00-START-HERE.md
- [ ] Read GETTING_STARTED.md
- [ ] Reviewed COST_ESTIMATION.md
- [ ] Understand architecture (ARCHITECTURE.md)

---

## Configuration Checklist

### File Setup
- [ ] Navigated to infrastructure/terraform directory
  ```powershell
  cd infrastructure/terraform
  ```
- [ ] Copied terraform.tfvars.example
  ```powershell
  copy terraform.tfvars.example terraform.tfvars
  ```
- [ ] Verified .gitignore exists
- [ ] Confirmed terraform.tfvars is in .gitignore

### Secrets Generation
- [ ] Generated strong database password (min 8 chars)
  ```powershell
  -join ((65..90) + (97..122) + (48..57) + (33,35,37,42,43,45,61,63,64) | Get-Random -Count 16 | ForEach-Object {[char]$_})
  ```
- [ ] Generated JWT secret (min 32 chars)
  ```powershell
  -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})
  ```
- [ ] Saved secrets securely (password manager)

### Configuration Values
- [ ] Updated terraform.tfvars with:
  - [ ] aws_region (e.g., us-east-1)
  - [ ] project_name (e.g., singha-loyalty)
  - [ ] environment (development/staging/production)
  - [ ] db_password (generated secret)
  - [ ] jwt_secret (generated secret)
  - [ ] db_instance_class (db.t3.micro for dev)
  - [ ] desired_count (1 for dev, 2+ for prod)
  - [ ] multi_az (false for dev, true for prod)

### Configuration Validation
- [ ] Reviewed all variables in terraform.tfvars
- [ ] Confirmed no placeholder values remain
- [ ] Verified cost implications
- [ ] Confirmed region selection

---

## Terraform Initialization Checklist

### Initialize Terraform
- [ ] Run terraform init
  ```powershell
  terraform init
  ```
- [ ] Verify successful initialization
- [ ] Check provider versions downloaded
- [ ] Review any warnings or errors

### Validate Configuration
- [ ] Run terraform fmt
  ```powershell
  terraform fmt
  ```
- [ ] Run terraform validate
  ```powershell
  terraform validate
  ```
- [ ] Fix any validation errors

### Review Plan
- [ ] Run terraform plan
  ```powershell
  terraform plan
  ```
- [ ] Review resources to be created (~50)
- [ ] Verify no unexpected changes
- [ ] Check estimated costs
- [ ] Confirm resource names are correct

---

## Deployment Checklist

### Pre-Deployment
- [ ] Saved current work
- [ ] Committed code to Git (except terraform.tfvars)
- [ ] Notified team of deployment
- [ ] Set aside 20-30 minutes
- [ ] Have coffee ready ☕

### Execute Deployment
- [ ] Run terraform apply
  ```powershell
  terraform apply
  ```
- [ ] Review plan one more time
- [ ] Type "yes" to confirm
- [ ] Monitor deployment progress
- [ ] Wait for completion (15-20 minutes)

### Verify Deployment
- [ ] Terraform apply completed successfully
- [ ] No errors in output
- [ ] All resources created
- [ ] Outputs displayed correctly

### Save Deployment Info
- [ ] Save outputs to file
  ```powershell
  terraform output > deployment-info.txt
  ```
- [ ] Record important values:
  - [ ] ECR repository URL
  - [ ] API endpoint
  - [ ] Frontend URL
  - [ ] RDS endpoint
  - [ ] ECS cluster name
  - [ ] ECS service name

---

## Post-Deployment Checklist

### Docker Image Deployment
- [ ] Navigate to server directory
  ```powershell
  cd ../../server
  ```
- [ ] Build Docker image
  ```powershell
  $ECR_REPO = terraform output -raw ecr_repository_url
  docker build -t ${ECR_REPO}:latest .
  ```
- [ ] Login to ECR
  ```powershell
  aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REPO
  ```
- [ ] Push image to ECR
  ```powershell
  docker push ${ECR_REPO}:latest
  ```
- [ ] Verify image in ECR console

### ECS Service Update
- [ ] Get cluster and service names
  ```powershell
  cd ../infrastructure/terraform
  $CLUSTER = terraform output -raw ecs_cluster_name
  $SERVICE = terraform output -raw ecs_service_name
  ```
- [ ] Force new deployment
  ```powershell
  aws ecs update-service --cluster $CLUSTER --service $SERVICE --force-new-deployment
  ```
- [ ] Wait for tasks to start (3-5 minutes)
- [ ] Verify tasks are running
  ```powershell
  aws ecs describe-services --cluster $CLUSTER --services $SERVICE
  ```

### Database Setup
- [ ] Get database connection info
  ```powershell
  $DB_ENDPOINT = terraform output -raw rds_endpoint
  $DB_NAME = terraform output -raw rds_database_name
  ```
- [ ] Run database migrations
  ```powershell
  cd ../../server
  node src/db/migrate.js
  ```
- [ ] Seed initial data (optional)
  ```powershell
  node src/db/seed.js
  ```
- [ ] Verify database tables created

### Frontend Deployment
- [ ] Build frontend
  ```powershell
  cd ../..
  npm run build
  ```
- [ ] Upload to S3
  ```powershell
  cd infrastructure/terraform
  $BUCKET = terraform output -raw frontend_bucket_name
  cd ../..
  aws s3 sync ./dist s3://${BUCKET}/ --delete
  ```
- [ ] Invalidate CloudFront cache
  ```powershell
  cd infrastructure/terraform
  $DISTRIBUTION = terraform output -raw cloudfront_distribution_id
  aws cloudfront create-invalidation --distribution-id $DISTRIBUTION --paths "/*"
  ```
- [ ] Wait for invalidation (2-5 minutes)

---

## Verification Checklist

### Infrastructure Verification
- [ ] VPC created with correct CIDR
- [ ] Subnets created in 2 AZs
- [ ] Security groups configured
- [ ] RDS instance running
- [ ] ECR repository exists
- [ ] ALB created and healthy
- [ ] ECS cluster created
- [ ] ECS service running
- [ ] S3 bucket created
- [ ] CloudFront distribution active

### Application Verification
- [ ] Test health endpoint
  ```powershell
  $API_ENDPOINT = terraform output -raw api_endpoint
  curl "${API_ENDPOINT}/health"
  ```
- [ ] Expected response: {"status":"healthy",...}
- [ ] Test API endpoints
  ```powershell
  curl "${API_ENDPOINT}/api/customers"
  ```
- [ ] Open frontend URL in browser
  ```powershell
  $FRONTEND_URL = terraform output -raw frontend_url
  Start-Process $FRONTEND_URL
  ```
- [ ] Frontend loads correctly
- [ ] Can navigate between pages
- [ ] API calls work from frontend

### Monitoring Verification
- [ ] CloudWatch log group exists
- [ ] Logs are flowing
  ```powershell
  aws logs tail /ecs/singha-loyalty --follow
  ```
- [ ] CloudWatch alarms created
- [ ] Container Insights enabled (if configured)
- [ ] RDS monitoring active

### Security Verification
- [ ] Security groups configured correctly
- [ ] RDS in private subnet
- [ ] No public access to RDS
- [ ] S3 bucket not publicly accessible
- [ ] Secrets in Secrets Manager
- [ ] IAM roles have minimal permissions

---

## Monitoring Setup Checklist

### CloudWatch Alarms
- [ ] Review existing alarms
- [ ] Create SNS topic for alerts (optional)
  ```powershell
  aws sns create-topic --name singha-loyalty-alerts
  ```
- [ ] Subscribe email to SNS topic
  ```powershell
  aws sns subscribe --topic-arn TOPIC_ARN --protocol email --notification-endpoint your-email@example.com
  ```
- [ ] Confirm email subscription
- [ ] Test alarm notifications

### Cost Monitoring
- [ ] Enable Cost Explorer
- [ ] Create billing alarm
  ```powershell
  aws cloudwatch put-metric-alarm `
      --alarm-name "MonthlyBillingAlert" `
      --alarm-description "Alert when monthly bill exceeds $100" `
      --metric-name EstimatedCharges `
      --namespace AWS/Billing `
      --statistic Maximum `
      --period 21600 `
      --evaluation-periods 1 `
      --threshold 100 `
      --comparison-operator GreaterThanThreshold
  ```
- [ ] Set up budget alerts in AWS Budgets
- [ ] Review cost allocation tags

### Logging
- [ ] Verify log retention settings
- [ ] Set up log insights queries
- [ ] Create CloudWatch dashboard (optional)
- [ ] Document log locations

---

## Documentation Checklist

### Internal Documentation
- [ ] Document deployment date
- [ ] Record configuration decisions
- [ ] Document any issues encountered
- [ ] Note any deviations from standard config
- [ ] Update team wiki/docs

### Access Documentation
- [ ] Document API endpoint
- [ ] Document frontend URL
- [ ] Document database connection info
- [ ] Document ECR repository
- [ ] Document AWS Console links

### Runbook Creation
- [ ] Document deployment procedure
- [ ] Document rollback procedure
- [ ] Document troubleshooting steps
- [ ] Document emergency contacts
- [ ] Document escalation procedures

---

## Security Hardening Checklist

### Immediate Security
- [ ] Rotate default passwords
- [ ] Review security group rules
- [ ] Enable VPC Flow Logs
- [ ] Review IAM policies
- [ ] Enable CloudTrail (if not already)

### Ongoing Security
- [ ] Schedule regular security audits
- [ ] Set up AWS GuardDuty (optional)
- [ ] Configure AWS WAF (optional)
- [ ] Enable AWS Shield (optional)
- [ ] Set up vulnerability scanning

---

## Backup & Recovery Checklist

### Backup Verification
- [ ] Verify RDS automated backups enabled
- [ ] Verify backup retention period (7 days)
- [ ] Test RDS snapshot creation
  ```powershell
  aws rds create-db-snapshot --db-instance-identifier singha-loyalty-db --db-snapshot-identifier test-snapshot
  ```
- [ ] Verify S3 versioning enabled
- [ ] Document backup locations

### Recovery Testing
- [ ] Document recovery procedures
- [ ] Test database restore (in dev)
- [ ] Test infrastructure recreation
- [ ] Document RTO/RPO
- [ ] Schedule regular DR tests

---

## Team Onboarding Checklist

### Knowledge Transfer
- [ ] Share documentation with team
- [ ] Walkthrough architecture
- [ ] Demonstrate deployment process
- [ ] Show monitoring dashboards
- [ ] Explain troubleshooting procedures

### Access Setup
- [ ] Create IAM users for team members
- [ ] Set up MFA for all users
- [ ] Grant appropriate permissions
- [ ] Share AWS Console access
- [ ] Share deployment credentials (securely)

### Training
- [ ] Train on Terraform basics
- [ ] Train on AWS services used
- [ ] Train on monitoring tools
- [ ] Train on incident response
- [ ] Schedule regular reviews

---

## Optimization Checklist

### Cost Optimization
- [ ] Review actual costs after 1 week
- [ ] Identify optimization opportunities
- [ ] Adjust instance sizes if needed
- [ ] Review auto-scaling settings
- [ ] Consider Reserved Instances (long-term)

### Performance Optimization
- [ ] Review CloudWatch metrics
- [ ] Identify bottlenecks
- [ ] Optimize database queries
- [ ] Adjust auto-scaling thresholds
- [ ] Review CloudFront cache hit ratio

### Security Optimization
- [ ] Review security group rules
- [ ] Audit IAM permissions
- [ ] Review CloudTrail logs
- [ ] Check for security findings
- [ ] Update security policies

---

## Maintenance Schedule

### Daily
- [ ] Monitor CloudWatch dashboards
- [ ] Review application logs
- [ ] Check ECS task health
- [ ] Review any alarms

### Weekly
- [ ] Review cost reports
- [ ] Check security alerts
- [ ] Review CloudWatch alarms
- [ ] Check backup status

### Monthly
- [ ] Update dependencies
- [ ] Review and optimize costs
- [ ] Security audit
- [ ] Backup verification
- [ ] Performance review

### Quarterly
- [ ] Architecture review
- [ ] Disaster recovery testing
- [ ] Documentation updates
- [ ] Team training
- [ ] Capacity planning

---

## Troubleshooting Checklist

### If Deployment Fails
- [ ] Review Terraform error messages
- [ ] Check AWS service quotas
- [ ] Verify AWS credentials
- [ ] Check for resource name conflicts
- [ ] Review CloudWatch logs
- [ ] Consult DEPLOYMENT_GUIDE.md

### If Application Not Working
- [ ] Check ECS task status
- [ ] Review application logs
- [ ] Verify database connectivity
- [ ] Check security group rules
- [ ] Test health endpoint
- [ ] Review ALB target health

### If Costs Too High
- [ ] Review Cost Explorer
- [ ] Check for unused resources
- [ ] Reduce task count
- [ ] Use smaller instance sizes
- [ ] Increase Spot percentage
- [ ] Consult COST_ESTIMATION.md

---

## Sign-Off Checklist

### Deployment Complete
- [ ] All infrastructure deployed
- [ ] Application running
- [ ] Monitoring configured
- [ ] Documentation updated
- [ ] Team notified

### Production Ready
- [ ] Security hardening complete
- [ ] Backups verified
- [ ] Monitoring alerts configured
- [ ] Runbooks created
- [ ] Team trained

### Handoff Complete
- [ ] Documentation shared
- [ ] Access granted
- [ ] Training completed
- [ ] Support procedures documented
- [ ] Maintenance schedule established

---

## 🎉 Deployment Complete!

Congratulations! You've successfully deployed the Singha Loyalty System infrastructure.

### Next Steps
1. Monitor for 24-48 hours
2. Optimize based on actual usage
3. Schedule regular reviews
4. Keep documentation updated

### Support
- Documentation: infrastructure/terraform/
- Quick Reference: QUICK_REFERENCE.md
- Troubleshooting: DEPLOYMENT_GUIDE.md

---

**Deployment Date**: _______________
**Deployed By**: _______________
**Environment**: _______________
**Version**: 1.0

---

**Save this checklist for future deployments!**
