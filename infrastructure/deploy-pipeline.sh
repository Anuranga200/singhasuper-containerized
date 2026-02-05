#!/bin/bash

# Deploy CI/CD Pipeline
# Usage: ./deploy-pipeline.sh

set -e

PROJECT_NAME="singha-loyalty"
AWS_REGION="us-east-1"

echo "🚀 Deploying CI/CD Pipeline"
echo ""

# Get inputs
read -p "GitHub Repository (username/repo): " GITHUB_REPO
read -p "GitHub Branch [main]: " GITHUB_BRANCH
GITHUB_BRANCH=${GITHUB_BRANCH:-main}
read -p "GitHub Personal Access Token: " -s GITHUB_TOKEN
echo ""

# Get ECS details from existing stack
ECS_CLUSTER=$(aws cloudformation describe-stacks \
    --stack-name $PROJECT_NAME-stack \
    --query 'Stacks[0].Outputs[?OutputKey==`ECSClusterName`].OutputValue' \
    --output text \
    --region $AWS_REGION)

ECS_SERVICE=$(aws cloudformation describe-stacks \
    --stack-name $PROJECT_NAME-stack \
    --query 'Stacks[0].Outputs[?OutputKey==`ECSServiceName`].OutputValue' \
    --output text \
    --region $AWS_REGION)

echo "📦 Deploying pipeline stack..."
aws cloudformation deploy \
    --template-file infrastructure/pipeline.yaml \
    --stack-name $PROJECT_NAME-pipeline \
    --parameter-overrides \
        ProjectName=$PROJECT_NAME \
        GitHubRepo=$GITHUB_REPO \
        GitHubBranch=$GITHUB_BRANCH \
        GitHubToken=$GITHUB_TOKEN \
        ECSClusterName=$ECS_CLUSTER \
        ECSServiceName=$ECS_SERVICE \
    --capabilities CAPABILITY_IAM \
    --region $AWS_REGION

echo ""
echo "✅ CI/CD Pipeline deployed successfully!"
echo ""
echo "🔄 Pipeline will automatically trigger on push to $GITHUB_BRANCH branch"
echo ""
