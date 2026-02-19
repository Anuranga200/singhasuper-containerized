# Terraform Backend Configuration
# Stores state in S3 with DynamoDB locking for team collaboration
# Requirements: 2.1

# IMPORTANT: Before using this backend configuration:
# 1. Create an S3 bucket for Terraform state
# 2. Enable versioning on the S3 bucket
# 3. Enable encryption on the S3 bucket
# 4. Create a DynamoDB table for state locking with primary key "LockID" (String)

# Uncomment and configure the backend after creating the required AWS resources
# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "eks-migration/exploration/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "terraform-state-lock"
#     
#     # Optional: Use a specific AWS profile
#     # profile = "your-aws-profile"
#   }
# }

# For initial setup, use local backend (default)
# Run these commands to create the S3 backend resources:
#
# aws s3api create-bucket \
#   --bucket your-terraform-state-bucket \
#   --region us-east-1
#
# aws s3api put-bucket-versioning \
#   --bucket your-terraform-state-bucket \
#   --versioning-configuration Status=Enabled
#
# aws s3api put-bucket-encryption \
#   --bucket your-terraform-state-bucket \
#   --server-side-encryption-configuration '{
#     "Rules": [{
#       "ApplyServerSideEncryptionByDefault": {
#         "SSEAlgorithm": "AES256"
#       }
#     }]
#   }'
#
# aws dynamodb create-table \
#   --table-name terraform-state-lock \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --billing-mode PAY_PER_REQUEST \
#   --region us-east-1

# Well-Architected Framework Alignment:
# - Security: State encryption at rest with S3 SSE
# - Reliability: State versioning for recovery
# - Operational Excellence: State locking prevents concurrent modifications
