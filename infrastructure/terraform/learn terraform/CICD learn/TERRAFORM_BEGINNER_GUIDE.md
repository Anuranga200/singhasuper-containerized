# Terraform for Beginners - Practical Guide

## 🎯 What is Terraform?

Think of Terraform as a **recipe book for cloud infrastructure**. Instead of clicking through AWS Console, you write code that describes what you want, and Terraform creates it for you.

**Analogy:**
- **Manual (Console)** = Cooking by following verbal instructions
- **Terraform** = Following a written recipe that anyone can use

---

## 📚 Table of Contents

1. [Installation & Setup](#installation--setup)
2. [Core Concepts](#core-concepts)
3. [Your First Terraform Command](#your-first-terraform-command)
4. [Understanding Your Project](#understanding-your-project)
5. [Hands-On: Deploy CI/CD Pipeline](#hands-on-deploy-cicd-pipeline)
6. [Common Commands](#common-commands)
7. [Troubleshooting](#troubleshooting)

---

## 🔧 Installation & Setup

### Step 1: Install Terraform

**Windows:**
```powershell
# Using Chocolatey
choco install terraform

# Or download from: https://www.terraform.io/downloads
```

**Verify Installation:**
```bash
terraform version
```

Expected output:
```
Terraform v1.6.0
```

### Step 2: Install AWS CLI

```powershell
# Download from: https://aws.amazon.com/cli/
```

### Step 3: Configure AWS Credentials

```bash
aws configure
```

Enter:
- AWS Access Key ID
- AWS Secret Access Key
- Default region: `us-east-1`
- Default output format: `json`

**Test it:**
```bash
aws sts get-caller-identity
```

You should see your AWS account details.

---

## 🧠 Core Concepts

### 1. Infrastructure as Code (IaC)

**Traditional Way:**
```
1. Login to AWS Console
2. Click "Create S3 Bucket"
3. Fill form
4. Click "Create"
5. Repeat for each resource
```

**Terraform Way:**
```hcl
resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-unique-bucket-name"
}
```

Then run: `terraform apply` → Bucket created!



### 2. Terraform Files

**Main Files in Your Project:**

```
infrastructure/terraform/
├── main.tf              # Main configuration (what to create)
├── variables.tf         # Input parameters (configurable values)
├── outputs.tf           # Output values (what to show after creation)
├── terraform.tfvars     # Your actual values (secrets, settings)
└── modules/             # Reusable components
    └── cicd-pipeline/   # CI/CD pipeline module
```

**Think of it like:**
- `main.tf` = The recipe
- `variables.tf` = Ingredient list
- `terraform.tfvars` = Your specific ingredients
- `outputs.tf` = What you get at the end

### 3. Resources

A **resource** is anything you create in AWS:

```hcl
resource "aws_s3_bucket" "my_bucket" {
  #      ↑ Type          ↑ Name (your choice)
  bucket = "my-bucket-name"
  #        ↑ Configuration
}
```

**Examples:**
- `aws_s3_bucket` = S3 bucket
- `aws_ecs_cluster` = ECS cluster
- `aws_codepipeline` = CodePipeline

### 4. Variables

Variables make your code reusable:

```hcl
# variables.tf
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "my-project"
}

# main.tf
resource "aws_s3_bucket" "bucket" {
  bucket = "${var.project_name}-artifacts"
  #         ↑ Uses the variable
}
```

### 5. Modules

Modules are reusable packages of resources:

```hcl
# Instead of writing 100 lines of code...
module "cicd_pipeline" {
  source = "./modules/cicd-pipeline"
  
  project_name = "my-app"
  # Module handles all the complexity!
}
```

**Think of modules as:**
- Pre-made LEGO sets
- You just configure them
- They handle the details



---

## 🚀 Your First Terraform Command

Let's start with the basics in your project:

### Step 1: Navigate to Terraform Directory

```bash
cd infrastructure/terraform
```

### Step 2: Initialize Terraform

```bash
terraform init
```

**What this does:**
- Downloads AWS provider (plugin to talk to AWS)
- Sets up backend (where to store state)
- Prepares modules

**Output you'll see:**
```
Initializing modules...
Initializing the backend...
Initializing provider plugins...
- Installing hashicorp/aws v5.x.x...


---

## 🚀 Your First Terraform Command

Let's start with something simple to understand how Terraform works.

### Exercise 1: Check Your Setup

```bash
# Navigate to terraform directory
cd infrastructure/terraform

# Check Terraform version
terraform version
```

**What you should see:**
```
Terraform v1.6.0 (or similar)
```

### Exercise 2: Understand the Workflow

Terraform has 3 main commands:

```
1. terraform init    → Download providers (like installing apps)
2. terraform plan    → Preview changes (like a shopping cart)
3. terraform apply   → Create resources (like checkout)
```

**Let's try them:**

```bash
# 1. Initialize (one-time setup)
terraform init
```

**What happens:**
- Downloads AWS provider
- Sets up backend
- Prepares workspace

**You'll see:**
```
Initializing modules...
Initializing provider plugins...
Terraform has been successfully initialized!
```

---

## 📖 Understanding Your Project

Let's explore your actual project files step by step.

### File 1: main.tf (The Recipe)

Open `infrastructure/terraform/main.tf`. Let's understand it section by section:

#### Section 1: Terraform Configuration

```hcl
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

**What this means:**
- `required_version`: Need Terraform 1.0 or higher
- `required_providers`: Need AWS provider version 5.x
- **Think of it as:** System requirements for a game

#### Section 2: AWS Provider

```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
```

**What this means:**
- `provider "aws"`: Connect to AWS
- `region = var.aws_region`: Which AWS region to use
- `default_tags`: Automatically tag all resources
- **Think of it as:** Logging into AWS with settings

#### Section 3: Modules (The Building Blocks)

```hcl
module "vpc" {
  source = "./modules/vpc"
  
  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
}
```

**What this means:**
- `module "vpc"`: Create a VPC using a pre-made module
- `source`: Where the module code is
- Other lines: Configuration for the module
- **Think of it as:** Using a LEGO set with instructions



### File 2: variables.tf (The Ingredient List)

Open `infrastructure/terraform/variables.tf`. Let's understand variables:

#### Example Variable:

```hcl
variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "singha-loyalty"
}
```

**Breaking it down:**
- `variable "project_name"`: Define a variable named "project_name"
- `description`: What this variable is for
- `type = string`: It's text (not a number or boolean)
- `default`: If you don't provide a value, use this

**How to use it:**
```hcl
# In main.tf
resource "aws_s3_bucket" "bucket" {
  bucket = "${var.project_name}-artifacts"
  #         ↑ This becomes "singha-loyalty-artifacts"
}
```

#### Variable Types:

```hcl
# String (text)
variable "name" {
  type    = string
  default = "my-app"
}

# Number
variable "count" {
  type    = number
  default = 2
}

# Boolean (true/false)
variable "enabled" {
  type    = bool
  default = true
}

# List (array)
variable "subnets" {
  type    = list(string)
  default = ["subnet-1", "subnet-2"]
}
```

### File 3: terraform.tfvars (Your Actual Values)

This is where YOU provide your specific values:

```hcl
# terraform.tfvars
project_name = "singha-loyalty"
aws_region   = "us-east-1"
db_password  = "MySecurePassword123!"
```

**Important:**
- This file contains secrets
- NEVER commit to Git
- Each person/environment has their own



### File 4: outputs.tf (What You Get)

Open `infrastructure/terraform/outputs.tf`. Outputs show you important information after creation:

```hcl
output "pipeline_name" {
  description = "Name of the CodePipeline"
  value       = module.cicd_pipeline[0].pipeline_name
}
```

**What this means:**
- After `terraform apply`, you'll see the pipeline name
- Useful for getting URLs, IDs, etc.
- **Think of it as:** Receipt after shopping

**View outputs:**
```bash
# See all outputs
terraform output

# See specific output
terraform output pipeline_name
```

---

## 🎓 Understanding the CI/CD Module

Let's dive into the CI/CD pipeline module you'll be using.

### Module Structure

```
modules/cicd-pipeline/
├── main.tf       # Resources to create
├── variables.tf  # What the module needs
└── outputs.tf    # What the module returns
```

### Module: main.tf (Simplified Explanation)

Open `infrastructure/terraform/modules/cicd-pipeline/main.tf`. Let's understand each resource:

#### Resource 1: S3 Bucket for Artifacts

```hcl
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket = "${var.project_name}-pipeline-artifacts-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-pipeline-artifacts"
  }
}
```

**What this creates:**
- An S3 bucket to store build artifacts
- Name: `singha-loyalty-pipeline-artifacts-285229572166`
- **Why:** CodePipeline needs somewhere to store files between stages

**Breaking down the name:**
- `${var.project_name}`: Your project name
- `pipeline-artifacts`: What it's for
- `${data.aws_caller_identity.current.account_id}`: Your AWS account ID
- **Result:** Unique bucket name

#### Resource 2: IAM Role for CodeBuild

```hcl
resource "aws_iam_role" "codebuild" {
  name = "${var.project_name}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}
```

**What this creates:**
- An IAM role (permissions) for CodeBuild
- **Why:** CodeBuild needs permission to access ECR, S3, CloudWatch
- **Think of it as:** Employee badge with access rights



#### Resource 3: CodeBuild Project

```hcl
resource "aws_codebuild_project" "main" {
  name          = "${var.project_name}-build"
  description   = "Build Docker image for ${var.project_name}"
  service_role  = aws_iam_role.codebuild.arn

  environment {
    compute_type = var.codebuild_compute_type
    image        = var.codebuild_image
    type         = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = var.buildspec_path
  }
}
```

**What this creates:**
- A CodeBuild project that builds your Docker image
- **Key settings:**
  - `service_role`: Uses the IAM role we created above
  - `privileged_mode = true`: Needed for Docker builds
  - `environment_variable`: Passes AWS account ID to build
  - `buildspec`: Path to build instructions

**Resource References:**
```hcl
service_role = aws_iam_role.codebuild.arn
#              ↑ References the role created above
```

**This is powerful!** Terraform knows:
1. Create the IAM role first
2. Then create CodeBuild project using that role
3. **You don't manage the order!**

#### Resource 4: CodePipeline

```hcl
resource "aws_codepipeline" "main" {
  name     = "${var.project_name}-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  stage {
    name = "Source"
    action {
      name     = "Source"
      category = "Source"
      owner    = "AWS"
      provider = "CodeStarSourceConnection"
      configuration = {
        ConnectionArn    = var.github_connection_arn
        FullRepositoryId = var.github_repository
        BranchName       = var.github_branch
      }
    }
  }

  stage {
    name = "Build"
    action {
      name     = "Build"
      category = "Build"
      owner    = "AWS"
      provider = "CodeBuild"
      configuration = {
        ProjectName = aws_codebuild_project.main.name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name     = "Deploy"
      category = "Deploy"
      owner    = "AWS"
      provider = "ECS"
      configuration = {
        ClusterName = var.ecs_cluster_name
        ServiceName = var.ecs_service_name
      }
    }
  }
}
```

**What this creates:**
- A 3-stage pipeline: Source → Build → Deploy
- **Stage 1 (Source):** Pulls code from GitHub
- **Stage 2 (Build):** Builds Docker image using CodeBuild
- **Stage 3 (Deploy):** Deploys to ECS

**Notice the reference:**
```hcl
ProjectName = aws_codebuild_project.main.name
#             ↑ Uses the CodeBuild project created above
```



---

## 🛠️ Hands-On: Deploy CI/CD Pipeline

Now let's actually deploy your CI/CD pipeline step by step!

### Step 1: Prepare Your Environment

```bash
# Navigate to terraform directory
cd infrastructure/terraform

# Check you're in the right place
ls
```

**You should see:**
```
main.tf
variables.tf
outputs.tf
terraform.tfvars.example
modules/
```

### Step 2: Create GitHub Connection (One-Time)

**Why:** AWS needs permission to access your GitHub repository.

1. Open browser: https://console.aws.amazon.com/codesuite/settings/connections
2. Click **"Create connection"**
3. Select **"GitHub"**
4. Name: `github-connection`
5. Click **"Connect to GitHub"**
6. Click **"Authorize AWS Connector for GitHub"**
7. **Copy the ARN** (looks like: `arn:aws:codestar-connections:us-east-1:285229572166:connection/xxxxx`)

**Save this ARN!** You'll need it in the next step.

### Step 3: Create Your Configuration File

```bash
# Copy the example file
cp terraform.tfvars.example terraform.tfvars

# Open it for editing
notepad terraform.tfvars
```

**Edit the file with your values:**

```hcl
# ==================== Basic Settings ====================
aws_region   = "us-east-1"
project_name = "singha-loyalty"
environment  = "production"

# ==================== Database ====================
db_username = "admin"
db_password = "YourSecurePassword123!"  # CHANGE THIS!

# ==================== JWT Secret ====================
jwt_secret = "your-super-secret-jwt-key-at-least-32-characters-long"  # CHANGE THIS!

# ==================== CI/CD Pipeline ====================
enable_cicd_pipeline = true

# Paste your GitHub connection ARN here
github_connection_arn = "arn:aws:codestar-connections:us-east-1:285229572166:connection/xxxxx"

# Your GitHub repository (format: username/repo)
github_repository = "yourusername/singhasuper-containerized"

# Branch to monitor
github_branch = "main"
```

**Important:**
- Replace `YourSecurePassword123!` with a strong password
- Replace the JWT secret with a random 32+ character string
- Replace `github_connection_arn` with your actual ARN from Step 2
- Replace `yourusername` with your GitHub username

**Save the file!**



### Step 4: Initialize Terraform

```bash
terraform init
```

**What happens:**
1. Downloads AWS provider (like installing an app)
2. Initializes modules
3. Sets up backend

**You'll see:**
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

Terraform has been successfully initialized!
```

**If you see errors:**
- Check your AWS credentials: `aws sts get-caller-identity`
- Make sure you're in the right directory

### Step 5: Validate Configuration

```bash
terraform validate
```

**What this does:**
- Checks syntax errors
- Validates configuration

**You should see:**
```
Success! The configuration is valid.
```

**If you see errors:**
- Read the error message carefully
- Check your terraform.tfvars file
- Make sure all required variables are set

### Step 6: Preview Changes (Plan)

```bash
terraform plan
```

**What this does:**
- Shows what will be created
- Like a shopping cart preview
- **NOTHING IS CREATED YET!**

**You'll see a long output like:**
```
Terraform will perform the following actions:

  # module.cicd_pipeline[0].aws_codebuild_project.main will be created
  + resource "aws_codebuild_project" "main" {
      + arn           = (known after apply)
      + badge_enabled = false
      + name          = "singha-loyalty-build"
      ...
    }

  # module.cicd_pipeline[0].aws_codepipeline.main will be created
  + resource "aws_codepipeline" "main" {
      + arn  = (known after apply)
      + name = "singha-loyalty-pipeline"
      ...
    }

  # module.cicd_pipeline[0].aws_s3_bucket.pipeline_artifacts will be created
  + resource "aws_s3_bucket" "pipeline_artifacts" {
      + bucket = "singha-loyalty-pipeline-artifacts-285229572166"
      ...
    }

Plan: 50 resources to add, 0 to change, 0 to destroy.
```

**Understanding the output:**
- `+ resource` = Will be created
- `~ resource` = Will be modified
- `- resource` = Will be destroyed
- `Plan: X to add` = Summary

**Take your time to review!**



### Step 7: Apply Changes (Create Resources)

```bash
terraform apply
```

**What this does:**
- Shows the plan again
- Asks for confirmation
- Creates all resources

**You'll see:**
```
Plan: 50 resources to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: 
```

**Type:** `yes` and press Enter

**Now watch the magic happen!**

```
module.vpc.aws_vpc.main: Creating...
module.vpc.aws_vpc.main: Creation complete after 3s [id=vpc-xxxxx]
module.security_groups.aws_security_group.alb: Creating...
module.security_groups.aws_security_group.alb: Creation complete after 5s
module.ecr.aws_ecr_repository.main: Creating...
module.ecr.aws_ecr_repository.main: Creation complete after 2s
module.cicd_pipeline[0].aws_s3_bucket.pipeline_artifacts: Creating...
module.cicd_pipeline[0].aws_s3_bucket.pipeline_artifacts: Creation complete after 4s
module.cicd_pipeline[0].aws_iam_role.codebuild: Creating...
module.cicd_pipeline[0].aws_iam_role.codebuild: Creation complete after 3s
module.cicd_pipeline[0].aws_codebuild_project.main: Creating...
module.cicd_pipeline[0].aws_codebuild_project.main: Creation complete after 2s
module.cicd_pipeline[0].aws_codepipeline.main: Creating...
module.cicd_pipeline[0].aws_codepipeline.main: Creation complete after 5s

Apply complete! Resources: 50 added, 0 changed, 0 destroyed.

Outputs:

pipeline_name = "singha-loyalty-pipeline"
api_endpoint = "http://singha-loyalty-alb-xxxxx.us-east-1.elb.amazonaws.com"
ecr_repository_url = "285229572166.dkr.ecr.us-east-1.amazonaws.com/singha-loyalty"
```

**🎉 Congratulations! Your infrastructure is created!**

**What just happened:**
1. Terraform created 50 resources in AWS
2. In the correct order (VPC → Security Groups → RDS → ECS → Pipeline)
3. All configured correctly
4. All connected together

**Time taken:** 10-15 minutes

### Step 8: Verify Creation

**Check the outputs:**
```bash
terraform output
```

**You'll see:**
```
api_endpoint = "http://singha-loyalty-alb-xxxxx.us-east-1.elb.amazonaws.com"
pipeline_name = "singha-loyalty-pipeline"
ecr_repository_url = "285229572166.dkr.ecr.us-east-1.amazonaws.com/singha-loyalty"
```

**Check in AWS Console:**

1. **CodePipeline:**
   - Go to: https://console.aws.amazon.com/codesuite/codepipeline/pipelines
   - You should see: `singha-loyalty-pipeline`

2. **CodeBuild:**
   - Go to: https://console.aws.amazon.com/codesuite/codebuild/projects
   - You should see: `singha-loyalty-build`

3. **S3:**
   - Go to: https://s3.console.aws.amazon.com/s3/buckets
   - You should see: `singha-loyalty-pipeline-artifacts-285229572166`

**Everything is there!** 🎉



### Step 9: Test the Pipeline

**Trigger the pipeline by pushing code:**

```bash
# Make a small change
echo "# CI/CD Test" >> README.md

# Commit
git add README.md
git commit -m "Test Terraform-created pipeline"

# Push
git push origin main
```

**Watch it work:**
1. Go to: https://console.aws.amazon.com/codesuite/codepipeline/pipelines/singha-loyalty-pipeline/view
2. You should see the pipeline start automatically!
3. Watch it go through: Source → Build → Deploy

**🎉 Your automated deployment is working!**

---

## 📚 Common Terraform Commands

### Essential Commands

```bash
# Initialize (first time or after adding modules)
terraform init

# Validate syntax
terraform validate

# Format code nicely
terraform fmt

# Preview changes
terraform plan

# Apply changes
terraform apply

# Apply without confirmation (use carefully!)
terraform apply -auto-approve

# Destroy everything (DANGEROUS!)
terraform destroy

# Show current state
terraform show

# List all resources
terraform state list

# View outputs
terraform output

# View specific output
terraform output pipeline_name
```

### Useful Commands

```bash
# Refresh state (sync with AWS)
terraform refresh

# Import existing resource
terraform import aws_s3_bucket.bucket my-bucket-name

# Taint resource (force recreation)
terraform taint module.cicd_pipeline[0].aws_codebuild_project.main

# Untaint resource
terraform untaint module.cicd_pipeline[0].aws_codebuild_project.main

# Graph dependencies
terraform graph | dot -Tpng > graph.png
```

### Workspace Commands

```bash
# List workspaces
terraform workspace list

# Create new workspace
terraform workspace new dev

# Switch workspace
terraform workspace select dev

# Show current workspace
terraform workspace show
```



---

## 🔧 Making Changes

### Scenario 1: Change Build Compute Type

**Current:** BUILD_GENERAL1_SMALL (3GB RAM)
**Want:** BUILD_GENERAL1_MEDIUM (7GB RAM)

**Step 1: Edit terraform.tfvars**
```hcl
codebuild_compute_type = "BUILD_GENERAL1_MEDIUM"
```

**Step 2: Preview changes**
```bash
terraform plan
```

**You'll see:**
```
  # module.cicd_pipeline[0].aws_codebuild_project.main will be updated in-place
  ~ resource "aws_codebuild_project" "main" {
      ~ environment {
          ~ compute_type = "BUILD_GENERAL1_SMALL" -> "BUILD_GENERAL1_MEDIUM"
        }
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

**Step 3: Apply**
```bash
terraform apply
```

**That's it!** Terraform updates only what changed.

### Scenario 2: Add Another Environment Variable

**Edit:** `modules/cicd-pipeline/main.tf`

```hcl
resource "aws_codebuild_project" "main" {
  # ... existing code ...
  
  environment {
    # ... existing variables ...
    
    environment_variable {
      name  = "NEW_VARIABLE"
      value = "new-value"
    }
  }
}
```

**Apply:**
```bash
terraform apply
```

### Scenario 3: Disable CI/CD Pipeline

**Edit terraform.tfvars:**
```hcl
enable_cicd_pipeline = false
```

**Apply:**
```bash
terraform apply
```

**Terraform will:**
- Destroy all CI/CD resources
- Keep everything else intact

**To re-enable:**
```hcl
enable_cicd_pipeline = true
```

```bash
terraform apply
```

---

## 🐛 Troubleshooting

### Error: "No valid credential sources found"

**Problem:** AWS credentials not configured

**Solution:**
```bash
aws configure
```

Enter your AWS credentials.

### Error: "Error acquiring the state lock"

**Problem:** Another terraform process is running

**Solution:**
```bash
# Wait for other process to finish, or force unlock
terraform force-unlock <lock-id>
```

### Error: "Resource already exists"

**Problem:** Resource was created manually or by another Terraform

**Solution:**
```bash
# Import existing resource
terraform import module.cicd_pipeline[0].aws_s3_bucket.pipeline_artifacts my-bucket-name
```

### Error: "Invalid for_each argument"

**Problem:** Variable is null or not set

**Solution:**
- Check terraform.tfvars has all required variables
- Run `terraform validate` to see which variable

### Changes Not Applying

**Problem:** Terraform not detecting changes

**Solution:**
```bash
# Refresh state
terraform refresh

# Or force recreation
terraform taint module.cicd_pipeline[0].aws_codebuild_project.main
terraform apply
```



---

## 🎓 Advanced Concepts

### 1. State Management

**What is State?**
- Terraform tracks what it created in a "state file"
- File: `terraform.tfstate`
- **NEVER edit this file manually!**

**View state:**
```bash
terraform show
```

**List resources in state:**
```bash
terraform state list
```

**Example output:**
```
module.cicd_pipeline[0].aws_codebuild_project.main
module.cicd_pipeline[0].aws_codepipeline.main
module.cicd_pipeline[0].aws_s3_bucket.pipeline_artifacts
module.vpc.aws_vpc.main
```

### 2. Remote State (Production)

**Problem:** Local state file is risky
- Lost if computer crashes
- Can't share with team

**Solution:** Store state in S3

**Create backend.tf:**
```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "singha-loyalty/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

**Initialize:**
```bash
terraform init -migrate-state
```

### 3. Workspaces (Multiple Environments)

**Use Case:** Separate dev, staging, production

```bash
# Create dev workspace
terraform workspace new dev

# Create prod workspace
terraform workspace new prod

# Switch to dev
terraform workspace select dev

# Apply (creates dev resources)
terraform apply

# Switch to prod
terraform workspace select prod

# Apply (creates prod resources)
terraform apply
```

**Each workspace has its own state!**

### 4. Data Sources

**What:** Read existing AWS resources

**Example:**
```hcl
# Read existing VPC
data "aws_vpc" "existing" {
  id = "vpc-xxxxx"
}

# Use it
resource "aws_subnet" "new" {
  vpc_id = data.aws_vpc.existing.id
}
```

### 5. Conditionals

**Create resource only if condition is true:**

```hcl
resource "aws_s3_bucket" "optional" {
  count = var.create_bucket ? 1 : 0
  
  bucket = "my-bucket"
}
```

**In your project:**
```hcl
module "cicd_pipeline" {
  count = var.enable_cicd_pipeline ? 1 : 0
  # Only created if enable_cicd_pipeline = true
}
```

### 6. Loops

**Create multiple similar resources:**

```hcl
variable "bucket_names" {
  default = ["bucket1", "bucket2", "bucket3"]
}

resource "aws_s3_bucket" "buckets" {
  for_each = toset(var.bucket_names)
  
  bucket = each.value
}
```



---

## 💡 Best Practices

### 1. Version Control

**Do commit:**
- ✅ `*.tf` files
- ✅ `*.tfvars.example`
- ✅ `.terraform.lock.hcl`

**Don't commit:**
- ❌ `terraform.tfvars` (contains secrets)
- ❌ `terraform.tfstate` (contains sensitive data)
- ❌ `.terraform/` directory

**Create .gitignore:**
```
# Terraform
.terraform/
*.tfstate
*.tfstate.backup
terraform.tfvars
.terraform.lock.hcl
```

### 2. Use Variables

**Bad:**
```hcl
resource "aws_s3_bucket" "bucket" {
  bucket = "my-hardcoded-bucket-name"
}
```

**Good:**
```hcl
resource "aws_s3_bucket" "bucket" {
  bucket = "${var.project_name}-bucket"
}
```

### 3. Use Modules

**Bad:** Copy-paste 100 lines of code for each environment

**Good:** Create a module, use it multiple times
```hcl
module "dev_pipeline" {
  source = "./modules/cicd-pipeline"
  environment = "dev"
}

module "prod_pipeline" {
  source = "./modules/cicd-pipeline"
  environment = "prod"
}
```

### 4. Always Run Plan First

```bash
# Bad
terraform apply -auto-approve

# Good
terraform plan
# Review output
terraform apply
```

### 5. Use Descriptive Names

**Bad:**
```hcl
resource "aws_s3_bucket" "b1" {
  bucket = "bucket"
}
```

**Good:**
```hcl
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket = "${var.project_name}-pipeline-artifacts"
}
```

### 6. Add Comments

```hcl
# S3 bucket for storing CodePipeline artifacts
# This bucket is used to pass files between pipeline stages
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket = "${var.project_name}-pipeline-artifacts"
}
```

### 7. Use Tags

```hcl
resource "aws_s3_bucket" "bucket" {
  bucket = "my-bucket"
  
  tags = {
    Name        = "Pipeline Artifacts"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }
}
```

---

## 🎯 Practice Exercises

### Exercise 1: View Your Infrastructure

```bash
# List all resources
terraform state list

# Show details of pipeline
terraform state show module.cicd_pipeline[0].aws_codepipeline.main

# View all outputs
terraform output
```

### Exercise 2: Make a Small Change

1. Edit `terraform.tfvars`
2. Change `log_retention_days = 7` to `log_retention_days = 3`
3. Run `terraform plan`
4. See what will change
5. Run `terraform apply`

### Exercise 3: Add a Tag

1. Edit `modules/cicd-pipeline/main.tf`
2. Find `aws_s3_bucket.pipeline_artifacts`
3. Add a new tag:
```hcl
tags = {
  Name = "${var.project_name}-pipeline-artifacts"
  Owner = "DevOps Team"  # Add this line
}
```
4. Run `terraform apply`

### Exercise 4: Explore State

```bash
# List all resources
terraform state list

# Count resources
terraform state list | wc -l

# Show specific resource
terraform state show module.vpc.aws_vpc.main
```



---

## 📖 Understanding Your Specific Project

Let's walk through your actual project structure:

### Your Project Architecture

```
infrastructure/terraform/
├── main.tf                    # Orchestrates all modules
├── variables.tf               # All input variables
├── outputs.tf                 # All outputs
├── terraform.tfvars          # Your values (create this)
├── terraform.tfvars.example  # Example values
└── modules/
    ├── vpc/                  # Network infrastructure
    ├── security-groups/      # Firewall rules
    ├── rds/                  # Database
    ├── ecr/                  # Docker registry
    ├── alb/                  # Load balancer
    ├── ecs/                  # Container orchestration
    ├── s3-frontend/          # Frontend hosting
    ├── cloudfront/           # CDN
    └── cicd-pipeline/        # CI/CD (what we focused on)
```

### How Modules Connect

```
main.tf calls modules in this order:

1. VPC Module
   ↓ (provides: vpc_id, subnet_ids)
   
2. Security Groups Module
   ↓ (provides: security_group_ids)
   
3. RDS Module (uses VPC, Security Groups)
   ↓ (provides: db_endpoint)
   
4. ECR Module
   ↓ (provides: repository_url)
   
5. ALB Module (uses VPC, Security Groups)
   ↓ (provides: target_group_arn, alb_dns)
   
6. ECS Module (uses VPC, Security Groups, ALB, RDS, ECR)
   ↓ (provides: cluster_name, service_name)
   
7. CI/CD Pipeline Module (uses ECR, ECS)
   ↓ (provides: pipeline_name)
```

### Module Communication Example

**In main.tf:**
```hcl
# Create VPC
module "vpc" {
  source = "./modules/vpc"
  # ... config ...
}

# Create ECS (uses VPC)
module "ecs" {
  source = "./modules/ecs"
  
  vpc_id            = module.vpc.vpc_id          # ← Uses VPC output
  public_subnet_ids = module.vpc.public_subnet_ids  # ← Uses VPC output
  # ... more config ...
}

# Create CI/CD (uses ECS)
module "cicd_pipeline" {
  source = "./modules/cicd-pipeline"
  
  ecs_cluster_name = module.ecs.cluster_name     # ← Uses ECS output
  ecs_service_name = module.ecs.service_name     # ← Uses ECS output
  # ... more config ...
}
```

**This is the power of Terraform!**
- Modules are independent
- They communicate through outputs
- Terraform manages dependencies automatically

---

## 🚀 Next Steps

### 1. Deploy Full Infrastructure

If you haven't deployed everything yet:

```bash
cd infrastructure/terraform

# Make sure all variables are set in terraform.tfvars
terraform apply
```

This creates:
- VPC and networking
- RDS database
- ECR repository
- ECS cluster and service
- Application Load Balancer
- S3 and CloudFront for frontend
- CI/CD pipeline

### 2. Explore Each Module

```bash
# Look at VPC module
cat modules/vpc/main.tf

# Look at ECS module
cat modules/ecs/main.tf

# Look at CI/CD module (you already know this one!)
cat modules/cicd-pipeline/main.tf
```

### 3. Customize Your Setup

**Try these modifications:**

1. **Change ECS task count:**
```hcl
# terraform.tfvars
desired_count = 3  # Instead of 2
```

2. **Enable Multi-AZ for RDS:**
```hcl
# terraform.tfvars
multi_az = true
```

3. **Change log retention:**
```hcl
# terraform.tfvars
log_retention_days = 14  # Instead of 7
```

### 4. Learn More

**Official Resources:**
- Terraform Docs: https://www.terraform.io/docs
- AWS Provider: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- Terraform Tutorials: https://learn.hashicorp.com/terraform

**Practice Projects:**
- Create a simple S3 bucket
- Create an EC2 instance
- Create a Lambda function

---

## 🎉 Congratulations!

You've learned:
- ✅ What Terraform is and why it's useful
- ✅ Core concepts (resources, variables, modules, outputs)
- ✅ How to read Terraform code
- ✅ How to deploy infrastructure
- ✅ How to make changes
- ✅ How to troubleshoot
- ✅ Best practices

**You're now a Terraform beginner!** 🚀

### Keep Learning

- Experiment with your project
- Try creating new resources
- Read other people's Terraform code
- Join Terraform community forums

### Remember

- Always run `terraform plan` before `apply`
- Never commit `terraform.tfvars` to Git
- Use modules for reusability
- Tag your resources
- Document your code

---

## 📞 Quick Reference Card

```bash
# Essential Commands
terraform init      # Initialize (first time)
terraform validate  # Check syntax
terraform plan      # Preview changes
terraform apply     # Create/update resources
terraform destroy   # Delete everything
terraform output    # View outputs

# State Commands
terraform state list                    # List resources
terraform state show <resource>         # Show resource details
terraform state rm <resource>           # Remove from state

# Workspace Commands
terraform workspace list                # List workspaces
terraform workspace new <name>          # Create workspace
terraform workspace select <name>       # Switch workspace

# Useful Flags
terraform apply -auto-approve           # Skip confirmation
terraform plan -out=plan.tfplan         # Save plan
terraform apply plan.tfplan             # Apply saved plan
terraform destroy -target=<resource>    # Destroy specific resource
```

---

**Happy Terraforming! 🎉**

If you have questions, refer back to this guide or check the official Terraform documentation.
