#!/bin/bash

# Deployment script for Singha Loyalty System
# Usage: ./deploy.sh [environment]

set -e

# Configuration
PROJECT_NAME="singha-loyalty"
AWS_REGION="us-east-1"
ENVIRONMENT="${1:-production}"

echo "🚀 Deploying Singha Loyalty System"
echo "📦 Environment: $ENVIRONMENT"
echo "🌍 Region: $AWS_REGION"
echo ""

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install it first."
    exit 1
fi

# Check if logged in to AWS
aws sts get-caller-identity > /dev/null 2>&1 || {
    echo "❌ Not logged in to AWS. Please run 'aws configure' first."
    exit 1
}

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "✅ AWS Account: $AWS_ACCOUNT_ID"
echo ""

# Step 1: Create ECR Repository
echo "📦 Step 1: Creating ECR repository..."
aws ecr describe-repositories --repository-names $PROJECT_NAME --region $AWS_REGION > /dev/null 2>&1 || \
aws ecr create-repository \
    --repository-name $PROJECT_NAME \
    --region $AWS_REGION \
    --image-scanning-configuration scanOnPush=true \
    --tags Key=Project,Value=$PROJECT_NAME

ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME"
echo "✅ ECR Repository: $ECR_URI"
echo ""

# Step 2: Build and Push Docker Image
echo "🐳 Step 2: Building Docker image..."
cd server
docker build -t $PROJECT_NAME:latest .
docker tag $PROJECT_NAME:latest $ECR_URI:latest
echo "✅ Docker image built"
echo ""

echo "🔐 Step 3: Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URI
echo "✅ Logged in to ECR"
echo ""

echo "⬆️  Step 4: Pushing image to ECR..."
docker push $ECR_URI:latest
echo "✅ Image pushed to ECR"
cd ..
echo ""

# Step 3: Deploy Infrastructure
echo "🏗️  Step 5: Deploying infrastructure..."
read -p "Enter DB Password: " -s DB_PASSWORD
echo ""
read -p "Enter JWT Secret: " -s JWT_SECRET
echo ""

aws cloudformation deploy \
    --template-file infrastructure/cloudformation-ecs.yaml \
    --stack-name $PROJECT_NAME-stack \
    --parameter-overrides \
        ProjectName=$PROJECT_NAME \
        Environment=$ENVIRONMENT \
        DBPassword=$DB_PASSWORD \
        JWTSecret=$JWT_SECRET \
        ContainerImage=$ECR_URI:latest \
    --capabilities CAPABILITY_IAM \
    --region $AWS_REGION

echo "✅ Infrastructure deployed"
echo ""

# Step 4: Get Outputs
echo "📊 Step 6: Getting deployment outputs..."
ALB_DNS=$(aws cloudformation describe-stacks \
    --stack-name $PROJECT_NAME-stack \
    --query 'Stacks[0].Outputs[?OutputKey==`ALBEndpoint`].OutputValue' \
    --output text \
    --region $AWS_REGION)

RDS_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name $PROJECT_NAME-stack \
    --query 'Stacks[0].Outputs[?OutputKey==`RDSEndpoint`].OutputValue' \
    --output text \
    --region $AWS_REGION)

echo ""
echo "✅ Deployment Complete!"
echo ""
echo "📝 Deployment Information:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 API Endpoint: http://$ALB_DNS"
echo "🗄️  RDS Endpoint: $RDS_ENDPOINT"
echo "🐳 ECR Repository: $ECR_URI"
echo ""
echo "📋 Next Steps:"
echo "1. Run database migrations:"
echo "   Connect to RDS and run: server/src/db/schema.sql"
echo ""
echo "2. Update frontend .env file:"
echo "   VITE_API_BASE_URL=http://$ALB_DNS/api"
echo ""
echo "3. Deploy frontend to S3/CloudFront (optional)"
echo ""
