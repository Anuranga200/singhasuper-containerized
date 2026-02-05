@echo off
REM ============================================
REM Terraform Deployment Script for Windows
REM ============================================
REM This script automates the Terraform deployment process

echo.
echo ========================================
echo   Singha Loyalty - Terraform Deployment
echo ========================================
echo.

REM Check if Terraform is installed
terraform version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Terraform is not installed or not in PATH
    echo Please install Terraform from: https://www.terraform.io/downloads
    exit /b 1
)

REM Check if AWS CLI is installed
aws --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] AWS CLI is not installed or not in PATH
    echo Please install AWS CLI from: https://aws.amazon.com/cli/
    exit /b 1
)

REM Check if terraform.tfvars exists
if not exist terraform.tfvars (
    echo [ERROR] terraform.tfvars not found
    echo Please copy terraform.tfvars.example to terraform.tfvars and configure it
    echo.
    echo Run: copy terraform.tfvars.example terraform.tfvars
    exit /b 1
)

echo [INFO] Prerequisites check passed
echo.

REM Initialize Terraform
echo [STEP 1/4] Initializing Terraform...
terraform init
if %errorlevel% neq 0 (
    echo [ERROR] Terraform initialization failed
    exit /b 1
)
echo [SUCCESS] Terraform initialized
echo.

REM Validate configuration
echo [STEP 2/4] Validating Terraform configuration...
terraform validate
if %errorlevel% neq 0 (
    echo [ERROR] Terraform validation failed
    exit /b 1
)
echo [SUCCESS] Configuration is valid
echo.

REM Plan deployment
echo [STEP 3/4] Creating deployment plan...
terraform plan -out=tfplan
if %errorlevel% neq 0 (
    echo [ERROR] Terraform plan failed
    exit /b 1
)
echo [SUCCESS] Plan created
echo.

REM Confirm deployment
echo [STEP 4/4] Ready to deploy infrastructure
echo.
echo This will create approximately 50+ AWS resources.
echo Estimated deployment time: 15-20 minutes
echo.
set /p CONFIRM="Do you want to proceed? (yes/no): "

if /i not "%CONFIRM%"=="yes" (
    echo [INFO] Deployment cancelled
    exit /b 0
)

REM Apply configuration
echo.
echo [INFO] Deploying infrastructure...
terraform apply tfplan
if %errorlevel% neq 0 (
    echo [ERROR] Terraform apply failed
    exit /b 1
)

REM Save outputs
echo.
echo [INFO] Saving deployment outputs...
terraform output > deployment-info.txt
echo [SUCCESS] Outputs saved to deployment-info.txt

echo.
echo ========================================
echo   Deployment Complete!
echo ========================================
echo.
echo Next steps:
echo 1. Review deployment-info.txt for important endpoints
echo 2. Build and push Docker image to ECR
echo 3. Run database migrations
echo 4. Deploy frontend to S3
echo.
echo For detailed instructions, see README.md
echo.

pause
