@echo off
REM Frontend CI/CD Pipeline Deployment Script (Windows)
REM Deploys S3, CloudFront, CodePipeline, and CodeBuild for React frontend

setlocal enabledelayedexpansion

REM Configuration
set PROJECT_NAME=singha-loyalty-frontend
set AWS_REGION=us-east-1
set STACK_NAME=%PROJECT_NAME%-pipeline

echo ========================================================
echo    Frontend CI/CD Pipeline Deployment
echo    Singha Loyalty System
echo ========================================================
echo.

REM Check AWS CLI
where aws >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] AWS CLI not found. Please install it first.
    exit /b 1
)

REM Check AWS credentials
echo [INFO] Checking AWS credentials...
aws sts get-caller-identity >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Not logged in to AWS. Please run 'aws configure' first.
    exit /b 1
)

for /f "tokens=*" %%i in ('aws sts get-caller-identity --query Account --output text') do set AWS_ACCOUNT_ID=%%i
echo [SUCCESS] AWS Account: %AWS_ACCOUNT_ID%
echo.

REM Get GitHub information
echo [INFO] GitHub Repository Configuration
echo ========================================================
echo.

set /p GITHUB_REPO="Enter GitHub repository (username/repo): "
if "%GITHUB_REPO%"=="" (
    echo [ERROR] GitHub repository is required
    exit /b 1
)

set /p GITHUB_BRANCH="Enter GitHub branch [main]: "
if "%GITHUB_BRANCH%"=="" set GITHUB_BRANCH=main

echo.
echo [INFO] GitHub Personal Access Token
echo Create token at: https://github.com/settings/tokens
echo Required scopes: repo, admin:repo_hook
echo.
set /p GITHUB_TOKEN="Enter GitHub token: "

if "%GITHUB_TOKEN%"=="" (
    echo [ERROR] GitHub token is required
    exit /b 1
)

REM Get backend API URL
echo.
echo [INFO] Backend API Configuration
echo ========================================================
echo.

echo [INFO] Checking for existing backend deployment...
for /f "tokens=*" %%i in ('aws cloudformation describe-stacks --stack-name singha-loyalty-stack --query "Stacks[0].Outputs[?OutputKey==`ALBEndpoint`].OutputValue" --output text 2^>nul') do set BACKEND_ALB=%%i

if not "%BACKEND_ALB%"=="" (
    echo [SUCCESS] Found backend ALB: %BACKEND_ALB%
    set BACKEND_API_URL=http://%BACKEND_ALB%/api
    echo    API URL: !BACKEND_API_URL!
    echo.
    set /p USE_DETECTED="Use this API URL? (y/n) [y]: "
    if "!USE_DETECTED!"=="" set USE_DETECTED=y
    
    if not "!USE_DETECTED!"=="y" (
        set /p BACKEND_API_URL="Enter backend API URL: "
    )
) else (
    echo [WARNING] Backend stack not found
    set /p BACKEND_API_URL="Enter backend API URL (e.g., http://alb-dns/api): "
)

if "%BACKEND_API_URL%"=="" (
    echo [ERROR] Backend API URL is required
    exit /b 1
)

REM S3 bucket name
echo.
set /p S3_BUCKET="Enter S3 bucket name [singha-loyalty-frontend]: "
if "%S3_BUCKET%"=="" set S3_BUCKET=singha-loyalty-frontend

REM Summary
echo.
echo ========================================================
echo    Deployment Configuration Summary
echo ========================================================
echo.
echo Project:         %PROJECT_NAME%
echo AWS Account:     %AWS_ACCOUNT_ID%
echo Region:          %AWS_REGION%
echo GitHub Repo:     %GITHUB_REPO%
echo GitHub Branch:   %GITHUB_BRANCH%
echo S3 Bucket:       %S3_BUCKET%
echo Backend API:     %BACKEND_API_URL%
echo.

set /p CONFIRM="Proceed with deployment? (y/n): "
if not "%CONFIRM%"=="y" (
    echo Deployment cancelled
    exit /b 0
)

echo.
echo [INFO] Starting deployment...
echo.

REM Deploy CloudFormation stack
echo [INFO] Deploying CloudFormation stack...
aws cloudformation deploy ^
    --template-file infrastructure/frontend-pipeline.yaml ^
    --stack-name %STACK_NAME% ^
    --parameter-overrides ^
        ProjectName=%PROJECT_NAME% ^
        GitHubRepo=%GITHUB_REPO% ^
        GitHubBranch=%GITHUB_BRANCH% ^
        GitHubToken=%GITHUB_TOKEN% ^
        S3BucketName=%S3_BUCKET% ^
        BackendAPIURL=%BACKEND_API_URL% ^
    --capabilities CAPABILITY_NAMED_IAM ^
    --region %AWS_REGION%

if %errorlevel% equ 0 (
    echo [SUCCESS] CloudFormation stack deployed successfully
) else (
    echo [ERROR] CloudFormation deployment failed
    exit /b 1
)

echo.
echo [INFO] Retrieving deployment outputs...

REM Get outputs
for /f "tokens=*" %%i in ('aws cloudformation describe-stacks --stack-name %STACK_NAME% --query "Stacks[0].Outputs[?OutputKey==`FrontendURL`].OutputValue" --output text --region %AWS_REGION%') do set CLOUDFRONT_URL=%%i
for /f "tokens=*" %%i in ('aws cloudformation describe-stacks --stack-name %STACK_NAME% --query "Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue" --output text --region %AWS_REGION%') do set CLOUDFRONT_ID=%%i
for /f "tokens=*" %%i in ('aws cloudformation describe-stacks --stack-name %STACK_NAME% --query "Stacks[0].Outputs[?OutputKey==`PipelineURL`].OutputValue" --output text --region %AWS_REGION%') do set PIPELINE_URL=%%i

echo.
echo ========================================================
echo    Deployment Completed Successfully!
echo ========================================================
echo.
echo [INFO] Deployment Information:
echo ========================================================
echo.
echo Frontend URL:
echo    %CLOUDFRONT_URL%
echo.
echo S3 Bucket:
echo    %S3_BUCKET%
echo.
echo CloudFront Distribution ID:
echo    %CLOUDFRONT_ID%
echo.
echo Pipeline URL:
echo    %PIPELINE_URL%
echo.
echo ========================================================
echo.

REM Trigger initial pipeline run
echo [INFO] Triggering initial pipeline run...
aws codepipeline start-pipeline-execution --name %PROJECT_NAME%-pipeline --region %AWS_REGION% >nul 2>nul

if %errorlevel% equ 0 (
    echo [SUCCESS] Pipeline triggered successfully
) else (
    echo [WARNING] Could not trigger pipeline automatically
    echo    You can trigger it manually from the AWS Console
)

echo.
echo [INFO] Next Steps:
echo ========================================================
echo.
echo 1. Monitor Pipeline:
echo    Open: %PIPELINE_URL%
echo    Wait for pipeline to complete (~5-10 minutes)
echo.
echo 2. Access Frontend:
echo    URL: %CLOUDFRONT_URL%
echo    Note: CloudFront may take 10-15 minutes to fully deploy
echo.
echo 3. Update Backend CORS:
echo    Add CloudFront URL to backend CORS configuration
echo    File: server/src/index.js
echo    Add: '%CLOUDFRONT_URL%'
echo.
echo 4. Test Application:
echo    - Open frontend URL
echo    - Test customer registration
echo    - Test admin login
echo    - Check browser console for errors
echo.
echo 5. Automatic Deployments:
echo    - Push code to GitHub (%GITHUB_BRANCH% branch)
echo    - Pipeline will automatically build and deploy
echo    - Monitor progress in CodePipeline console
echo.
echo ========================================================
echo.

REM Save configuration
(
echo # Frontend Pipeline Configuration
echo # Generated: %date% %time%
echo.
echo STACK_NAME=%STACK_NAME%
echo PROJECT_NAME=%PROJECT_NAME%
echo S3_BUCKET=%S3_BUCKET%
echo CLOUDFRONT_ID=%CLOUDFRONT_ID%
echo CLOUDFRONT_URL=%CLOUDFRONT_URL%
echo BACKEND_API_URL=%BACKEND_API_URL%
echo GITHUB_REPO=%GITHUB_REPO%
echo GITHUB_BRANCH=%GITHUB_BRANCH%
echo AWS_REGION=%AWS_REGION%
) > .frontend-pipeline-config

echo [SUCCESS] Configuration saved to .frontend-pipeline-config
echo.

REM Create helper scripts
(
echo @echo off
echo REM Invalidate CloudFront cache
echo.
echo for /f "tokens=*" %%%%i in ^('type .frontend-pipeline-config ^| findstr CLOUDFRONT_ID'^) do set %%%%i
echo for /f "tokens=*" %%%%i in ^('type .frontend-pipeline-config ^| findstr AWS_REGION'^) do set %%%%i
echo.
echo echo [INFO] Invalidating CloudFront cache...
echo aws cloudfront create-invalidation --distribution-id %%CLOUDFRONT_ID%% --paths "/*" --region %%AWS_REGION%%
echo.
echo echo [SUCCESS] Invalidation created
) > invalidate-cloudfront.bat

(
echo @echo off
echo REM Manually trigger pipeline
echo.
echo for /f "tokens=*" %%%%i in ^('type .frontend-pipeline-config ^| findstr PROJECT_NAME'^) do set %%%%i
echo for /f "tokens=*" %%%%i in ^('type .frontend-pipeline-config ^| findstr AWS_REGION'^) do set %%%%i
echo.
echo echo [INFO] Triggering pipeline...
echo aws codepipeline start-pipeline-execution --name %%PROJECT_NAME%%-pipeline --region %%AWS_REGION%%
echo.
echo echo [SUCCESS] Pipeline triggered
echo echo Monitor at: https://console.aws.amazon.com/codesuite/codepipeline/pipelines/%%PROJECT_NAME%%-pipeline/view
) > trigger-pipeline.bat

echo [SUCCESS] Helper scripts created:
echo    - invalidate-cloudfront.bat - Clear CloudFront cache
echo    - trigger-pipeline.bat - Manually trigger pipeline
echo.

echo [SUCCESS] Frontend CI/CD Pipeline deployment complete!
echo.

endlocal
