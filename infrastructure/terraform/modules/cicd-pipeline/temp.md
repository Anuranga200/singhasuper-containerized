output "cicd_setup_instructions" {
  value = var.enable_cicd_pipeline ? <<-EOT

    🚀 CI/CD Pipeline Setup:

    Your pipeline is configured but needs a GitHub connection:

    1. Create GitHub Connection (one-time setup):
       - Go to: https://console.aws.amazon.com/codesuite/settings/connections       
       - Click "Create connection"
       - Choose "GitHub"
       - Name: github-connection
       - Click "Connect to GitHub" and authorize
       - Copy the connection ARN

    2. Update terraform.tfvars with the connection ARN:
       github_connection_arn = "arn:aws:codestar-connections:us-east-1:ACCOUNT_ID:connection/xxxxx"
       github_repository     = "yourusername/singhasuper-containerized"
       github_branch         = "main"

    3. Re-run terraform apply:
       terraform apply

    4. Pipeline will automatically trigger on git push!

    📊 Monitor Pipeline:
       - Pipeline: https://console.aws.amazon.com/codesuite/codepipeline/pipelines/${module.cicd_pipeline[0].pipeline_name}/view
       - Build Logs: https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups/log-group/${module.cicd_pipeline[0].codebuild_log_group_name}    
  EOT
  : "CI/CD pipeline is not enabled. Set enable_cicd_pipeline = true to enable it."
}