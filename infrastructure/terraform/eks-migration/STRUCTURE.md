# EKS Migration Project Structure

This document describes the complete directory structure for the EKS migration Terraform project.

## Directory Tree

```
eks-migration/
├── README.md                           # Main documentation
├── STRUCTURE.md                        # This file - directory structure guide
│
├── environments/                       # Environment-specific configurations
│   └── exploration/                    # Exploration environment
│       ├── backend.tf                  # S3 backend configuration
│       ├── main.tf                     # Root module composition
│       ├── variables.tf                # Input variables
│       ├── outputs.tf                  # Output values
│       ├── terraform.tfvars.example    # Example variable values
│       └── terraform.tfvars            # Actual values (gitignored)
│
└── modules/                            # Reusable Terraform modules
    │
    ├── eks-cluster/                    # EKS cluster module
    │   ├── README.md                   # Module documentation
    │   ├── main.tf                     # EKS cluster resource
    │   ├── iam.tf                      # Cluster IAM role and policies
    │   ├── security-groups.tf          # Cluster security group
    │   ├── variables.tf                # Module input variables
    │   └── outputs.tf                  # Module outputs
    │
    ├── eks-node-group/                 # EKS node group module
    │   ├── README.md                   # Module documentation
    │   ├── main.tf                     # Node group resource
    │   ├── iam.tf                      # Node IAM role and policies
    │   ├── security-groups.tf          # Node security group
    │   ├── launch-template.tf          # Custom launch template (optional)
    │   ├── variables.tf                # Module input variables
    │   └── outputs.tf                  # Module outputs
    │
    ├── kubernetes-resources/           # Kubernetes resources module
    │   ├── README.md                   # Module documentation
    │   ├── main.tf                     # Kubernetes provider config
    │   ├── namespace.tf                # Namespace resource
    │   ├── secrets.tf                  # Secret resource
    │   ├── deployment.tf               # Deployment resource
    │   ├── service.tf                  # Service resource
    │   ├── ingress.tf                  # Ingress resource
    │   ├── pdb.tf                      # PodDisruptionBudget
    │   ├── hpa.tf                      # HorizontalPodAutoscaler (optional)
    │   ├── variables.tf                # Module input variables
    │   └── outputs.tf                  # Module outputs
    │
    └── alb-integration/                # ALB integration module
        ├── README.md                   # Module documentation
        ├── main.tf                     # Target group and listener rule
        ├── data.tf                     # Data sources for existing ALB
        ├── variables.tf                # Module input variables
        └── outputs.tf                  # Module outputs
```

## File Purposes

### Root Level Files

- **README.md**: Main documentation with overview, prerequisites, quick start, and cost estimation
- **STRUCTURE.md**: This file - detailed directory structure explanation

### Environment Files (environments/exploration/)

- **backend.tf**: Configures S3 backend for remote state storage with encryption and locking
- **main.tf**: Orchestrates all modules, defines data sources, and composes the complete infrastructure
- **variables.tf**: Defines all input variables with descriptions, types, defaults, and validations
- **outputs.tf**: Defines outputs for cluster info, kubectl commands, verification commands, and cost estimates
- **terraform.tfvars.example**: Example variable values with comments (safe to commit)
- **terraform.tfvars**: Actual variable values with secrets (gitignored, never commit)

### Module Files (modules/*/

Each module follows a consistent structure:

- **README.md**: Module-specific documentation with usage examples
- **main.tf**: Primary resources for the module
- **iam.tf**: IAM roles, policies, and attachments (if applicable)
- **security-groups.tf**: Security groups and rules (if applicable)
- **data.tf**: Data sources for existing resources (if applicable)
- **variables.tf**: Module input variables
- **outputs.tf**: Module output values

## Module Dependencies

```
eks-cluster
    ↓
eks-node-group (depends on cluster)
    ↓
kubernetes-resources (depends on cluster and nodes)
    ↓
alb-integration (depends on kubernetes resources)
```

## State Management

- **Backend**: S3 bucket with encryption
- **Locking**: DynamoDB table prevents concurrent modifications
- **State File**: `eks-migration/exploration/terraform.tfstate`
- **Versioning**: Enabled on S3 bucket for state history

## Security Considerations

### Files to Gitignore

```
# Terraform state files
*.tfstate
*.tfstate.*
*.tfstate.backup

# Variable files with secrets
terraform.tfvars
*.auto.tfvars

# Terraform directories
.terraform/
.terraform.lock.hcl

# Crash logs
crash.log
crash.*.log

# Override files
override.tf
override.tf.json
*_override.tf
*_override.tf.json
```

### Sensitive Variables

The following variables contain sensitive data and should never be committed:
- `db_password`
- `db_user`
- `db_host`
- `jwt_secret`

These are marked as `sensitive = true` in variables.tf and should only be in terraform.tfvars (gitignored).

## Module Isolation

Each module is self-contained and can be:
- Tested independently
- Reused in different environments
- Versioned separately (if moved to separate repos)
- Modified without affecting other modules

## Best Practices

1. **Never commit terraform.tfvars** - contains secrets
2. **Always use backend.tf** - for team collaboration
3. **Use modules** - for reusability and organization
4. **Document everything** - README files in each module
5. **Version providers** - lock provider versions in backend.tf
6. **Tag resources** - use default_tags in provider config
7. **Validate inputs** - use validation blocks in variables
8. **Output useful info** - kubectl commands, verification steps

## Next Steps

After creating this structure:

1. Implement each module (tasks 2-6)
2. Create standalone Kubernetes YAML manifests (task 8)
3. Add monitoring configuration (task 9)
4. Write comprehensive documentation (tasks 10-17)
5. Test the complete deployment
6. Document rollback procedures

## References

- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [AWS EKS Terraform Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- [Kubernetes Terraform Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
