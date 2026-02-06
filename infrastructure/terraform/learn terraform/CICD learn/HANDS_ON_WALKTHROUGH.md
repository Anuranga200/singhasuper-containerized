# Hands-On Terraform Walkthrough - CI/CD Pipeline

## 🎯 Goal
Deploy a complete CI/CD pipeline using Terraform in 30 minutes.

## 📋 Prerequisites Checklist

Before starting, make sure you have:

- [ ] Terraform installed (`terraform version`)
- [ ] AWS CLI installed (`aws --version`)
- [ ] AWS credentials configured (`aws sts get-caller-identity`)
- [ ] Git repository with your code
- [ ] Text editor (VS Code, Notepad++, etc.)

---

## 🚀 Step-by-Step Walkthrough

### Step 1: Navigate to Project (1 minute)

```bash
# Open terminal/command prompt
cd infrastructure/terraform

# Verify you're in the right place
ls
```

**Expected output:**
```
main.tf
variables.tf
outputs.tf
terraform.tfvars.example
modules/
```

✅ **Checkpoint:** You see these files

---

### Step 2: Create GitHub Connection (5 minutes)

**Why:** AWS needs permission to access your GitHub repo.

1. Open browser: https://console.aws.amazon.com/codesuite/settings/connections

2. Click **"Create connection"**

3. Choose **"GitHub"**

4. Enter name: `github-connection`

5. Click **"Connect to GitHub"**

6. Click **"Authorize AWS Connector for GitHub"**

7. **IMPORTANT:** Copy the ARN that appears
   ```
   Example: arn:aws:codestar-connections:us-east-1:285229572166:connection/abc123
   ```

8. Save this ARN in a text file temporarily

✅ **Checkpoint:** You have the connection ARN copied

---

### Step 3: Create Configuration File (5 minutes)

```bash
# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Open for editing (Windows)
notepad terraform.tfvars

# Or (if you have VS Code)
code terraform.tfvars
```

**Edit these values:**

```hcl
# ==================== REQUIRED: Change These! ====================

# Your AWS region
aws_region = "us-east-1"

# Your project name
project_name = "singha-loyalty"

# Environment
environment = "production"

# Database password (CHANGE THIS!)
db_password = "MySecurePassword123!"

# JWT secret (CHANGE THIS! - must be 32+ characters)
jwt_secret = "my-super-secret-jwt-key-at-least-32-characters-long"

# ==================== CI/CD Configuration ====================

# Enable CI/CD pipeline
enable_cicd_pipeline = true

# Paste your GitHub connection ARN here
github_connection_arn = "arn:aws:codestar-connections:us-east-1:285229572166:connection/YOUR-CONNECTION-ID"

# Your GitHub repository (format: username/repo)
github_repository = "yourusername/singhasuper-containerized"

# Branch to monitor
github_branch = "main"
```

**Save the file!**

✅ **Checkpoint:** File saved with your values

---



### Step 4: Initialize Terraform (2 minutes)

```bash
terraform init
```

**What you'll see:**
```
Initializing modules...
- cicd_pipeline in modules/cicd-pipeline
- cloudfront in modules/cloudfront
- ecr in modules/ecr
- ecs in modules/ecs
- rds in modules/rds
- s3_frontend in modules/s3-frontend
- security_groups in modules/security-groups
- vpc in modules/vpc

Initializing the backend...

Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.31.0...
- Installed hashicorp/aws v5.31.0

Terraform has been successfully initialized!
```

✅ **Checkpoint:** See "successfully initialized"

**If you see errors:**
- Check AWS credentials: `aws sts get-caller-identity`
- Make sure you're in `infrastructure/terraform` directory

---

### Step 5: Validate Configuration (1 minute)

```bash
terraform validate
```

**Expected output:**
```
Success! The configuration is valid.
```

✅ **Checkpoint:** Configuration is valid

**If you see errors:**
- Read the error message
- Check terraform.tfvars for typos
- Make sure all required variables are set

---

### Step 6: Preview Changes (3 minutes)

```bash
terraform plan
```

**What you'll see:**
- Long output showing what will be created
- Summary at the end

**Look for:**
```
Plan: 50 resources to add, 0 to change, 0 to destroy.
```

**Take time to review!** Look for:
- S3 bucket names
- CodeBuild project name
- CodePipeline name
- IAM roles

✅ **Checkpoint:** Plan shows resources to create

---

### Step 7: Apply Changes (10 minutes)

```bash
terraform apply
```

**You'll see the plan again, then:**
```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value:
```

**Type:** `yes` and press Enter

**Now watch the creation process:**
```
module.vpc.aws_vpc.main: Creating...
module.vpc.aws_vpc.main: Creation complete after 3s
module.security_groups.aws_security_group.alb: Creating...
module.security_groups.aws_security_group.alb: Creation complete after 5s
module.ecr.aws_ecr_repository.main: Creating...
module.ecr.aws_ecr_repository.main: Creation complete after 2s
...
(many more resources)
...
module.cicd_pipeline[0].aws_codepipeline.main: Creating...
module.cicd_pipeline[0].aws_codepipeline.main: Creation complete after 5s

Apply complete! Resources: 50 added, 0 changed, 0 destroyed.

Outputs:

api_endpoint = "http://singha-loyalty-alb-xxxxx.us-east-1.elb.amazonaws.com"
pipeline_name = "singha-loyalty-pipeline"
ecr_repository_url = "285229572166.dkr.ecr.us-east-1.amazonaws.com/singha-loyalty"
```

**This takes 10-15 minutes. Be patient!**

✅ **Checkpoint:** See "Apply complete!"

---

### Step 8: Verify Creation (3 minutes)

**Check outputs:**
```bash
terraform output
```

**You should see:**
```
api_endpoint = "http://singha-loyalty-alb-xxxxx.us-east-1.elb.amazonaws.com"
ecs_cluster_name = "singha-loyalty-cluster"
pipeline_name = "singha-loyalty-pipeline"
ecr_repository_url = "285229572166.dkr.ecr.us-east-1.amazonaws.com/singha-loyalty"
```

**Verify in AWS Console:**

1. **CodePipeline:**
   - Go to: https://console.aws.amazon.com/codesuite/codepipeline/pipelines
   - Look for: `singha-loyalty-pipeline`
   - ✅ Should be there!

2. **CodeBuild:**
   - Go to: https://console.aws.amazon.com/codesuite/codebuild/projects
   - Look for: `singha-loyalty-build`
   - ✅ Should be there!

3. **S3:**
   - Go to: https://s3.console.aws.amazon.com/s3/buckets
   - Look for: `singha-loyalty-pipeline-artifacts-285229572166`
   - ✅ Should be there!

✅ **Checkpoint:** All resources visible in AWS Console

---

### Step 9: Test the Pipeline (5 minutes)

**Trigger the pipeline:**

```bash
# Make a small change
echo "# Terraform CI/CD Test" >> README.md

# Commit
git add README.md
git commit -m "Test Terraform-deployed pipeline"

# Push
git push origin main
```

**Watch it work:**

1. Go to: https://console.aws.amazon.com/codesuite/codepipeline/pipelines/singha-loyalty-pipeline/view

2. You should see:
   - **Source** stage: In Progress → Succeeded
   - **Build** stage: In Progress → Succeeded (3-5 min)
   - **Deploy** stage: In Progress → Succeeded (5-10 min)

3. **Total time:** 10-15 minutes for first deployment

✅ **Checkpoint:** Pipeline completes successfully

---

## 🎉 Success!

You've successfully:
- ✅ Deployed infrastructure with Terraform
- ✅ Created a CI/CD pipeline
- ✅ Tested automatic deployment

**Your pipeline now:**
- Automatically builds on every git push
- Deploys to ECS with zero downtime
- All managed by Terraform!

---

## 🔍 What Did We Create?

### Infrastructure Resources (50 total)

**Networking:**
- 1 VPC
- 4 Subnets (2 public, 2 private)
- 1 Internet Gateway
- 2 Route Tables
- 3 Security Groups

**Database:**
- 1 RDS MySQL instance
- 1 DB Subnet Group

**Container Infrastructure:**
- 1 ECR Repository
- 1 ECS Cluster
- 1 ECS Service
- 1 ECS Task Definition
- 1 Application Load Balancer
- 1 Target Group

**CI/CD Pipeline:**
- 1 S3 Bucket (artifacts)
- 1 CodeBuild Project
- 1 CodePipeline
- 2 IAM Roles (CodeBuild, CodePipeline)
- 2 IAM Policies
- 1 CloudWatch Log Group

**Frontend:**
- 1 S3 Bucket (frontend)
- 1 CloudFront Distribution

---

## 📊 Understanding What Happened

### Terraform Workflow

```
1. terraform init
   ↓
   Downloaded AWS provider
   Initialized modules
   
2. terraform validate
   ↓
   Checked syntax
   Validated configuration
   
3. terraform plan
   ↓
   Calculated what to create
   Showed preview
   
4. terraform apply
   ↓
   Created resources in order
   Managed dependencies
   Saved state
```

### Resource Creation Order

Terraform automatically determined the order:

```
1. VPC (foundation)
   ↓
2. Subnets, Internet Gateway (networking)
   ↓
3. Security Groups (firewall rules)
   ↓
4. RDS, ECR (data storage)
   ↓
5. ALB (load balancer)
   ↓
6. ECS (containers)
   ↓
7. CI/CD Pipeline (automation)
```

**You didn't have to manage this order!** Terraform figured it out.

---

## 🎓 What You Learned

### Terraform Concepts

1. **Infrastructure as Code**
   - Wrote code instead of clicking
   - Version controlled
   - Repeatable

2. **Modules**
   - Reusable components
   - Encapsulated logic
   - Easy to maintain

3. **Variables**
   - Configurable values
   - Environment-specific
   - Secure secrets

4. **Outputs**
   - Important information
   - Resource references
   - Easy access

5. **State Management**
   - Tracks resources
   - Enables updates
   - Manages dependencies

---

## 🔄 Making Changes

### Example 1: Change Build Compute Type

**Current:** Small (3GB RAM)
**Want:** Medium (7GB RAM)

```bash
# Edit terraform.tfvars
notepad terraform.tfvars

# Change this line:
codebuild_compute_type = "BUILD_GENERAL1_MEDIUM"

# Preview change
terraform plan

# Apply change
terraform apply
```

**Terraform will:**
- Update only the CodeBuild project
- Keep everything else unchanged

### Example 2: Disable CI/CD Pipeline

```bash
# Edit terraform.tfvars
enable_cicd_pipeline = false

# Apply
terraform apply
```

**Terraform will:**
- Destroy CI/CD resources
- Keep VPC, ECS, RDS, etc.

### Example 3: Add More ECS Tasks

```bash
# Edit terraform.tfvars
desired_count = 4  # Instead of 2

# Apply
terraform apply
```

**Terraform will:**
- Update ECS service
- Launch 2 more tasks

---

## 🐛 Troubleshooting

### Issue: "Error acquiring state lock"

**Solution:**
```bash
# Wait a moment, then try again
# Or force unlock (use carefully!)
terraform force-unlock <lock-id>
```

### Issue: "Resource already exists"

**Solution:**
```bash
# Import existing resource
terraform import module.cicd_pipeline[0].aws_s3_bucket.pipeline_artifacts bucket-name
```

### Issue: "Invalid credentials"

**Solution:**
```bash
# Reconfigure AWS
aws configure

# Test
aws sts get-caller-identity
```

### Issue: Plan shows unexpected changes

**Solution:**
```bash
# Refresh state
terraform refresh

# Then plan again
terraform plan
```

---

## 📚 Next Steps

### 1. Explore Your Infrastructure

```bash
# List all resources
terraform state list

# Show specific resource
terraform state show module.cicd_pipeline[0].aws_codepipeline.main

# View outputs
terraform output
```

### 2. Make Small Changes

Try these exercises:
- Change log retention days
- Add a tag to resources
- Change ECS task count

### 3. Learn More Modules

Explore other modules:
```bash
cat modules/vpc/main.tf
cat modules/ecs/main.tf
cat modules/rds/main.tf
```

### 4. Read Documentation

- Terraform Docs: https://www.terraform.io/docs
- AWS Provider: https://registry.terraform.io/providers/hashicorp/aws
- Your project's README files

---

## ✅ Completion Checklist

- [ ] Terraform installed and working
- [ ] AWS credentials configured
- [ ] GitHub connection created
- [ ] terraform.tfvars configured
- [ ] `terraform init` successful
- [ ] `terraform validate` successful
- [ ] `terraform plan` reviewed
- [ ] `terraform apply` completed
- [ ] Resources visible in AWS Console
- [ ] Pipeline tested and working
- [ ] Outputs reviewed
- [ ] Made at least one change

---

## 🎉 Congratulations!

You've successfully:
- Deployed infrastructure with Terraform
- Created a working CI/CD pipeline
- Learned Terraform basics
- Made your first infrastructure changes

**You're now ready to:**
- Manage infrastructure as code
- Deploy changes confidently
- Collaborate with your team
- Scale your infrastructure

---

## 📞 Need Help?

**Documentation:**
- Beginner Guide: `TERRAFORM_BEGINNER_GUIDE.md`
- Cheat Sheet: `TERRAFORM_CHEAT_SHEET.md`
- CI/CD Setup: `CICD_SETUP_GUIDE.md`

**Commands:**
```bash
# Get help
terraform -help

# Get help for specific command
terraform apply -help

# View version
terraform version
```

**Community:**
- Terraform Forums: https://discuss.hashicorp.com/c/terraform-core
- AWS Forums: https://forums.aws.amazon.com
- Stack Overflow: https://stackoverflow.com/questions/tagged/terraform

---

**Happy Terraforming! 🚀**
