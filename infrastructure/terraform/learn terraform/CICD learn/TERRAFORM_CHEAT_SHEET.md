# Terraform Cheat Sheet - Quick Reference

## 🚀 Essential Commands

```bash
# Initialize project (first time)
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt

# Preview changes
terraform plan

# Apply changes
terraform apply

# Apply without confirmation
terraform apply -auto-approve

# Destroy everything
terraform destroy

# Show current state
terraform show

# View outputs
terraform output
```

---

## 📁 File Structure

```
project/
├── main.tf              # Main configuration
├── variables.tf         # Input variables
├── outputs.tf           # Output values
├── terraform.tfvars     # Your values (DON'T COMMIT!)
├── terraform.tfstate    # State file (DON'T EDIT!)
└── modules/             # Reusable modules
    └── my-module/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

---

## 🔧 Basic Syntax

### Resource
```hcl
resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-unique-bucket-name"
  
  tags = {
    Name = "My Bucket"
  }
}
```

### Variable
```hcl
variable "project_name" {
  description = "Project name"
  type        = string
  default     = "my-project"
}
```

### Output
```hcl
output "bucket_name" {
  description = "Name of the bucket"
  value       = aws_s3_bucket.my_bucket.bucket
}
```

### Module
```hcl
module "vpc" {
  source = "./modules/vpc"
  
  cidr_block = "10.0.0.0/16"
}
```

---

## 🔗 References

```hcl
# Reference resource attribute
aws_s3_bucket.my_bucket.arn

# Reference variable
var.project_name

# Reference module output
module.vpc.vpc_id

# Reference data source
data.aws_ami.ubuntu.id
```

---

## 📊 Variable Types

```hcl
# String
variable "name" {
  type = string
}

# Number
variable "count" {
  type = number
}

# Boolean
variable "enabled" {
  type = bool
}

# List
variable "subnets" {
  type = list(string)
}

# Map
variable "tags" {
  type = map(string)
}

# Object
variable "config" {
  type = object({
    name = string
    size = number
  })
}
```

---

## 🎯 Common Patterns

### Conditional Resource
```hcl
resource "aws_s3_bucket" "optional" {
  count = var.create_bucket ? 1 : 0
  
  bucket = "my-bucket"
}
```

### Loop (for_each)
```hcl
resource "aws_s3_bucket" "buckets" {
  for_each = toset(["bucket1", "bucket2"])
  
  bucket = each.value
}
```

### Loop (count)
```hcl
resource "aws_instance" "servers" {
  count = 3
  
  ami           = "ami-xxxxx"
  instance_type = "t2.micro"
  
  tags = {
    Name = "Server-${count.index}"
  }
}
```

---

## 🔍 State Commands

```bash
# List resources
terraform state list

# Show resource details
terraform state show aws_s3_bucket.my_bucket

# Remove resource from state
terraform state rm aws_s3_bucket.my_bucket

# Move resource in state
terraform state mv aws_s3_bucket.old aws_s3_bucket.new

# Pull remote state
terraform state pull

# Push local state
terraform state push
```

---

## 🌍 Workspace Commands

```bash
# List workspaces
terraform workspace list

# Create workspace
terraform workspace new dev

# Switch workspace
terraform workspace select dev

# Show current workspace
terraform workspace show

# Delete workspace
terraform workspace delete dev
```

---

## 📦 Module Usage

```hcl
module "example" {
  source = "./modules/example"
  
  # Required inputs
  name = "my-resource"
  
  # Optional inputs
  enabled = true
}

# Access module outputs
output "example_id" {
  value = module.example.resource_id
}
```

---

## 🐛 Debugging

```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform apply

# Log to file
export TF_LOG_PATH=./terraform.log
terraform apply

# Disable logging
unset TF_LOG
unset TF_LOG_PATH

# Validate syntax
terraform validate

# Check formatting
terraform fmt -check

# Show dependency graph
terraform graph
```

---

## 🔐 Best Practices

### ✅ Do
- Use version control (Git)
- Use remote state (S3)
- Use modules for reusability
- Tag all resources
- Use variables for flexibility
- Run `terraform plan` before `apply`
- Use `.gitignore` for sensitive files

### ❌ Don't
- Commit `terraform.tfvars`
- Commit `terraform.tfstate`
- Edit state file manually
- Use `apply -auto-approve` in production
- Hardcode values
- Skip `terraform plan`

---

## 📝 .gitignore

```
# Terraform
.terraform/
*.tfstate
*.tfstate.backup
*.tfstate.lock.info
terraform.tfvars
.terraform.lock.hcl
crash.log
override.tf
override.tf.json
```

---

## 🎨 Formatting

```bash
# Format all files
terraform fmt

# Format specific file
terraform fmt main.tf

# Check if formatted
terraform fmt -check

# Format recursively
terraform fmt -recursive
```

---

## 🔄 Import Existing Resources

```bash
# Import S3 bucket
terraform import aws_s3_bucket.my_bucket my-bucket-name

# Import EC2 instance
terraform import aws_instance.my_server i-1234567890abcdef0

# Import with module
terraform import module.vpc.aws_vpc.main vpc-xxxxx
```

---

## 💾 Backend Configuration

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "project/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

---

## 🎯 Targeting

```bash
# Apply to specific resource
terraform apply -target=aws_s3_bucket.my_bucket

# Destroy specific resource
terraform destroy -target=aws_s3_bucket.my_bucket

# Plan for specific module
terraform plan -target=module.vpc
```

---

## 🔧 Useful Flags

```bash
# Skip confirmation
-auto-approve

# Save plan
-out=plan.tfplan

# Apply saved plan
terraform apply plan.tfplan

# Specify var file
-var-file=prod.tfvars

# Set variable
-var="project_name=my-app"

# Refresh state
-refresh=true

# Parallelism
-parallelism=10
```

---

## 📊 Output Formats

```bash
# JSON output
terraform output -json

# Specific output
terraform output bucket_name

# Raw output (no quotes)
terraform output -raw bucket_name
```

---

## 🚨 Emergency Commands

```bash
# Force unlock state
terraform force-unlock <lock-id>

# Refresh state
terraform refresh

# Taint resource (force recreation)
terraform taint aws_instance.my_server

# Untaint resource
terraform untaint aws_instance.my_server

# Replace resource
terraform apply -replace=aws_instance.my_server
```

---

## 📚 Quick Tips

1. **Always run plan first**: `terraform plan` before `apply`
2. **Use modules**: Don't repeat yourself
3. **Version your providers**: Lock provider versions
4. **Use remote state**: Don't lose your state file
5. **Tag everything**: Makes management easier
6. **Use workspaces**: Separate environments
7. **Document your code**: Add comments
8. **Test changes**: Use `terraform plan`
9. **Backup state**: Keep state file safe
10. **Learn gradually**: Start simple, add complexity

---

## 🔗 Useful Links

- **Terraform Docs**: https://www.terraform.io/docs
- **AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws
- **Terraform Registry**: https://registry.terraform.io
- **Learn Terraform**: https://learn.hashicorp.com/terraform
- **Community**: https://discuss.hashicorp.com/c/terraform-core

---

**Print this and keep it handy! 📄**
