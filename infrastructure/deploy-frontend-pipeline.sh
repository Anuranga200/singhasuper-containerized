#!/bin/bash

# Frontend CI/CD Pipeline Deployment Script
# Deploys S3, CloudFront, CodePipeline, and CodeBuild for React frontend

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="singha-loyalty-frontend"
AWS_REGION="us-east-1"
STACK_NAME="${PROJECT_NAME}-pipeline"

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Frontend CI/CD Pipeline Deployment                  ║${NC}"
echo -e "${BLUE}║   Singha Loyalty System                                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI not found. Please install it first.${NC}"
    exit 1
fi

# Check if logged in to AWS
echo -e "${YELLOW}🔐 Checking AWS credentials...${NC}"
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo -e "${RED}❌ Not logged in to AWS. Please run 'aws configure' first.${NC}"
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✅ AWS Account: $AWS_ACCOUNT_ID${NC}"
echo ""

# Get GitHub information
echo -e "${YELLOW}📝 GitHub Repository Configuration${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

read -p "Enter GitHub repository (username/repo): " GITHUB_REPO
if [ -z "$GITHUB_REPO" ]; then
    echo -e "${RED}❌ GitHub repository is required${NC}"
    exit 1
fi

read -p "Enter GitHub branch [main]: " GITHUB_BRANCH
GITHUB_BRANCH=${GITHUB_BRANCH:-main}

echo ""
echo -e "${YELLOW}🔑 GitHub Personal Access Token${NC}"
echo -e "${BLUE}Create token at: https://github.com/settings/tokens${NC}"
echo -e "${BLUE}Required scopes: repo, admin:repo_hook${NC}"
echo ""
read -sp "Enter GitHub token: " GITHUB_TOKEN
echo ""

if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${RED}❌ GitHub token is required${NC}"
    exit 1
fi

# Get backend API URL
echo ""
echo -e "${YELLOW}🔗 Backend API Configuration${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Try to get ALB DNS from backend stack
echo -e "${YELLOW}Checking for existing backend deployment...${NC}"
BACKEND_ALB=$(aws cloudformation describe-stacks \
    --stack-name singha-loyalty-stack \
    --query 'Stacks[0].Outputs[?OutputKey==`ALBEndpoint`].OutputValue' \
    --output text 2>/dev/null || echo "")

if [ -n "$BACKEND_ALB" ]; then
    echo -e "${GREEN}✅ Found backend ALB: $BACKEND_ALB${NC}"
    BACKEND_API_URL="http://${BACKEND_ALB}/api"
    echo -e "${GREEN}   API URL: $BACKEND_API_URL${NC}"
    echo ""
    read -p "Use this API URL? (y/n) [y]: " USE_DETECTED
    USE_DETECTED=${USE_DETECTED:-y}
    
    if [ "$USE_DETECTED" != "y" ]; then
        read -p "Enter backend API URL: " BACKEND_API_URL
    fi
else
    echo -e "${YELLOW}⚠️  Backend stack not found${NC}"
    read -p "Enter backend API URL (e.g., http://alb-dns/api): " BACKEND_API_URL
fi

if [ -z "$BACKEND_API_URL" ]; then
    echo -e "${RED}❌ Backend API URL is required${NC}"
    exit 1
fi

# S3 bucket name
echo ""
read -p "Enter S3 bucket name [singha-loyalty-frontend]: " S3_BUCKET
S3_BUCKET=${S3_BUCKET:-singha-loyalty-frontend}

# Summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Deployment Configuration Summary                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Project:${NC}         $PROJECT_NAME"
echo -e "${YELLOW}AWS Account:${NC}     $AWS_ACCOUNT_ID"
echo -e "${YELLOW}Region:${NC}          $AWS_REGION"
echo -e "${YELLOW}GitHub Repo:${NC}     $GITHUB_REPO"
echo -e "${YELLOW}GitHub Branch:${NC}   $GITHUB_BRANCH"
echo -e "${YELLOW}S3 Bucket:${NC}       $S3_BUCKET"
echo -e "${YELLOW}Backend API:${NC}     $BACKEND_API_URL"
echo ""

read -p "Proceed with deployment? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo -e "${YELLOW}Deployment cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}🚀 Starting deployment...${NC}"
echo ""

# Deploy CloudFormation stack
echo -e "${YELLOW}📦 Deploying CloudFormation stack...${NC}"
aws cloudformation deploy \
    --template-file infrastructure/frontend-pipeline.yaml \
    --stack-name $STACK_NAME \
    --parameter-overrides \
        ProjectName=$PROJECT_NAME \
        GitHubRepo=$GITHUB_REPO \
        GitHubBranch=$GITHUB_BRANCH \
        GitHubToken=$GITHUB_TOKEN \
        S3BucketName=$S3_BUCKET \
        BackendAPIURL=$BACKEND_API_URL \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $AWS_REGION

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ CloudFormation stack deployed successfully${NC}"
else
    echo -e "${RED}❌ CloudFormation deployment failed${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}📊 Retrieving deployment outputs...${NC}"

# Get outputs
CLOUDFRONT_URL=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`FrontendURL`].OutputValue' \
    --output text \
    --region $AWS_REGION)

CLOUDFRONT_ID=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue' \
    --output text \
    --region $AWS_REGION)

PIPELINE_URL=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`PipelineURL`].OutputValue' \
    --output text \
    --region $AWS_REGION)

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ Deployment Completed Successfully!                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📝 Deployment Information:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}🌐 Frontend URL:${NC}"
echo -e "   $CLOUDFRONT_URL"
echo ""
echo -e "${YELLOW}📦 S3 Bucket:${NC}"
echo -e "   $S3_BUCKET"
echo ""
echo -e "${YELLOW}🔄 CloudFront Distribution ID:${NC}"
echo -e "   $CLOUDFRONT_ID"
echo ""
echo -e "${YELLOW}🚀 Pipeline URL:${NC}"
echo -e "   $PIPELINE_URL"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Trigger initial pipeline run
echo -e "${YELLOW}🔄 Triggering initial pipeline run...${NC}"
aws codepipeline start-pipeline-execution \
    --name ${PROJECT_NAME}-pipeline \
    --region $AWS_REGION > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Pipeline triggered successfully${NC}"
else
    echo -e "${YELLOW}⚠️  Could not trigger pipeline automatically${NC}"
    echo -e "${YELLOW}   You can trigger it manually from the AWS Console${NC}"
fi

echo ""
echo -e "${GREEN}📋 Next Steps:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "1. ${YELLOW}Monitor Pipeline:${NC}"
echo -e "   Open: $PIPELINE_URL"
echo -e "   Wait for pipeline to complete (~5-10 minutes)"
echo ""
echo -e "2. ${YELLOW}Access Frontend:${NC}"
echo -e "   URL: $CLOUDFRONT_URL"
echo -e "   Note: CloudFront may take 10-15 minutes to fully deploy"
echo ""
echo -e "3. ${YELLOW}Update Backend CORS:${NC}"
echo -e "   Add CloudFront URL to backend CORS configuration"
echo -e "   File: server/src/index.js"
echo -e "   Add: '$CLOUDFRONT_URL'"
echo ""
echo -e "4. ${YELLOW}Test Application:${NC}"
echo -e "   - Open frontend URL"
echo -e "   - Test customer registration"
echo -e "   - Test admin login"
echo -e "   - Check browser console for errors"
echo ""
echo -e "5. ${YELLOW}Automatic Deployments:${NC}"
echo -e "   - Push code to GitHub ($GITHUB_BRANCH branch)"
echo -e "   - Pipeline will automatically build and deploy"
echo -e "   - Monitor progress in CodePipeline console"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Save configuration
cat > .frontend-pipeline-config << EOF
# Frontend Pipeline Configuration
# Generated: $(date)

STACK_NAME=$STACK_NAME
PROJECT_NAME=$PROJECT_NAME
S3_BUCKET=$S3_BUCKET
CLOUDFRONT_ID=$CLOUDFRONT_ID
CLOUDFRONT_URL=$CLOUDFRONT_URL
BACKEND_API_URL=$BACKEND_API_URL
GITHUB_REPO=$GITHUB_REPO
GITHUB_BRANCH=$GITHUB_BRANCH
AWS_REGION=$AWS_REGION
EOF

echo -e "${GREEN}✅ Configuration saved to .frontend-pipeline-config${NC}"
echo ""

# Create helper scripts
cat > invalidate-cloudfront.sh << 'EOF'
#!/bin/bash
# Invalidate CloudFront cache

source .frontend-pipeline-config

echo "🔄 Invalidating CloudFront cache..."
aws cloudfront create-invalidation \
    --distribution-id $CLOUDFRONT_ID \
    --paths "/*" \
    --region $AWS_REGION

echo "✅ Invalidation created"
EOF

chmod +x invalidate-cloudfront.sh

cat > trigger-pipeline.sh << 'EOF'
#!/bin/bash
# Manually trigger pipeline

source .frontend-pipeline-config

echo "🚀 Triggering pipeline..."
aws codepipeline start-pipeline-execution \
    --name ${PROJECT_NAME}-pipeline \
    --region $AWS_REGION

echo "✅ Pipeline triggered"
echo "Monitor at: https://console.aws.amazon.com/codesuite/codepipeline/pipelines/${PROJECT_NAME}-pipeline/view"
EOF

chmod +x trigger-pipeline.sh

echo -e "${GREEN}✅ Helper scripts created:${NC}"
echo -e "   - ${YELLOW}invalidate-cloudfront.sh${NC} - Clear CloudFront cache"
echo -e "   - ${YELLOW}trigger-pipeline.sh${NC} - Manually trigger pipeline"
echo ""

echo -e "${GREEN}🎉 Frontend CI/CD Pipeline deployment complete!${NC}"
echo ""
