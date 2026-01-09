Build and Reuse a VPC Module with Versioning

Lab Overview
In this lab, you will:

Create a reusable VPC module from scratch
Use the module locally in a root configuration
Version the module using Git tags
Publish the module to GitHub
Consume the module with version constraints
Iterate on the module and release a new version

Prerequisites:

OpenTofu installed (1.6.0 or later)
AWS CLI configured with credentials
Git installed and configured
GitHub account (for publishing)
Text editor or IDE

What You'll Build:
A production-ready VPC module that creates:

VPC with customizable CIDR
Public and private subnets across multiple AZs
Internet Gateway
NAT Gateway (optional)
Route tables and associations
Proper tagging and naming

tofu-modules-lab/
├── modules/
│   └── aws-vpc/          # Our VPC module
└── environments/
    └── dev/              # Example usage

#  1. Deploy and Test the Module

 cd environments/dev

# Initialize
tofu init

# Review the plan
tofu plan

# Deploy
tofu apply

# Verify outputs
tofu output

# 2  Verification Steps:

#Check VPC in AWS Console
#Verify subnets are in correct AZs
#Confirm route tables are properly configured
#Test NAT Gateway functionality (deploy an instance in private subnet)

# 3 Versioning and Publishing the Module
#Initialize Git Repository

# Return to project root
cd ../../

# Initialize Git (if not already done)
git init

# Create .gitignore
cat > .gitignore << 'EOF'
# Local .terraform directories
**/.terraform/*

# .tfstate files
*.tfstate
*.tfstate.*

# Crash log files
crash.log
crash.*.log

# Lock files
.terraform.lock.hcl

# Override files
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Ignore CLI configuration files
.terraformrc
terraform.rc

# Ignore sensitive files
*.pem
*.key
*.crt
EOF

# Add all module files
git add modules/aws-vpc/
git commit -m "Initial VPC module - v1.0.0"

# Tag the first version
git tag -a v1.0.0 -m "Version 1.0.0: Initial stable release"

# 4 Publish to GitHub
# Create a new repository on GitHub first, then:

# Add remote
git remote add origin https://github.com/YOUR-USERNAME/terraform-aws-vpc.git

# Push code and tags
git push -u origin main
git push origin v1.0.0  

# 5 Use Module from GitHub
mkdir -p environments/staging
cd environments/staging

terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Using module from GitHub with version constraint

# File: environments/staging/main.tf

module "vpc" {
  source = "git::https://github.com/YOUR-USERNAME/terraform-aws-vpc.git//modules/aws-vpc?ref=v1.0.0"
  
  vpc_name           = "staging-vpc"
  vpc_cidr           = "10.1.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  
  public_subnet_cidrs = [
    "10.1.1.0/24",
    "10.1.2.0/24",
    "10.1.3.0/24"
  ]
  
  private_subnet_cidrs = [
    "10.1.10.0/24",
    "10.1.20.0/24",
    "10.1.30.0/24"
  ]
  
  enable_nat_gateway = true
  single_nat_gateway = false  # High availability for staging
  
  tags = {
    Environment = "staging"
  }
}

output "vpc_details" {
  value = {
    vpc_id             = module.vpc.vpc_id
    public_subnet_ids  = module.vpc.public_subnet_ids
    private_subnet_ids = module.vpc.private_subnet_ids
  }
}

# test: 
tofu init
tofu plan

#########################################################################
# Iterating and Releasing New Versions
Add New Feature (VPC Flow Logs)
Let's add VPC Flow Logs as a new feature for version 1.1.0.

# File: modules/aws-vpc/variables.tf
# Update: modules/aws-vpc/variables.tf (add these variables)
variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = false
}

variable "flow_logs_retention_days" {
  description = "Number of days to retain flow logs"
  type        = number
  default     = 7
  
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.flow_logs_retention_days)
    error_message = "Retention days must be a valid CloudWatch Logs retention period."
  }
}

# Update: modules/aws-vpc/main.tf (add at the end)
# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "flow_logs" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/aws/vpc/flowlogs/${var.vpc_name}"
  retention_in_days = var.flow_logs_retention_days
  
  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-flow-logs"
    }
  )
}

# IAM Role for VPC Flow Logs
resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.vpc_name}-flow-logs-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

# IAM Policy for VPC Flow Logs
resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.vpc_name}-flow-logs-policy"
  role  = aws_iam_role.flow_logs[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}

# VPC Flow Logs
resource "aws_flow_log" "this" {
  count                = var.enable_flow_logs ? 1 : 0
  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"
  iam_role_arn         = aws_iam_role.flow_logs[0].arn
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow_logs[0].arn
  
  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-flow-logs"
    }
  )
}

# Update: modules/aws-vpc/outputs.tf (add these outputs)

output "flow_logs_log_group_name" {
  description = "Name of the CloudWatch Log Group for VPC Flow Logs"
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.flow_logs[0].name : null
}

output "flow_logs_iam_role_arn" {
  description = "ARN of the IAM role for VPC Flow Logs"
  value       = var.enable_flow_logs ? aws_iam_role.flow_logs[0].arn : null
}

# Test and Release Version 1.1.0
# Test the changes locally
cd environments/dev

# Update to use flow logs
# Edit main.tf and add:
#   enable_flow_logs = true

tofu init -upgrade
tofu plan
tofu apply

# Verify flow logs are working

##########################################################################
# Commit and tag the new version:
cd ../../

git add modules/aws-vpc/
git commit -m "Add VPC Flow Logs feature - v1.1.0"
git tag -a v1.1.0 -m "Version 1.1.0: Add VPC Flow Logs support"

git push origin main
git push origin v1.1.0


# Use Different Module Versions
# Create a production environment that uses the stable v1.0.0, while staging uses v1.1.0:

environments/production/main.tf:

module "vpc" {
  source = "git::https://github.com/YOUR-USERNAME/terraform-aws-vpc.git//modules/aws-vpc?ref=v1.0.0"
  
  vpc_name           = "prod-vpc"
  vpc_cidr           = "10.2.0.0/16"
  # ... configuration without flow logs
}

environments/staging/main.tf (update):

module "vpc" {
  source = "git::https://github.com/YOUR-USERNAME/terraform-aws-vpc.git//modules/aws-vpc?ref=v1.1.0"
  
  vpc_name           = "staging-vpc"
  vpc_cidr           = "10.1.0.0/16"
  enable_flow_logs   = true  # New feature!
  # ... rest of configuration
}

##############################################################################
# Advanced - Using a Community Module

# Compare with AWS VPC Module from Library.tf
# Let's see how a well-established community module works:
#   Create: environments/comparison/main.tf
terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Community module from Terraform Registry (compatible with OpenTofu)
module "vpc_community" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"
  
  name = "comparison-vpc"
  cidr = "10.3.0.0/16"
  
  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.3.1.0/24", "10.3.2.0/24", "10.3.3.0/24"]
  public_subnets  = ["10.3.101.0/24", "10.3.102.0/24", "10.3.103.0/24"]
  
  enable_nat_gateway = true
  single_nat_gateway = true
  enable_dns_hostnames = true
  
  tags = {
    Environment = "comparison"
    Source      = "community-module"
  }
}

output "community_vpc_id" {
  value = module.vpc_community.vpc_id
}

output "community_private_subnets" {
  value = module.vpc_community.private_subnets
}

# Compare Features: 
cd environments/comparison
tofu init
tofu plan

# Note the differences in:
# - Available features
# - Default behaviors
# - Output values
# - Configuration complexity

Lab Completion Checklist
Verify you've completed all steps:

 Created VPC module with all required files
 Module has proper structure (versions.tf, variables.tf, main.tf, outputs.tf)
 Deployed module locally and verified it works
 Initialized Git repository
 Tagged version v1.0.0
 Published module to GitHub
 Used module from GitHub with version constraint
 Added new feature (VPC Flow Logs)
 Tagged version v1.1.0
 Tested multiple version usage
 Compared with community module

 Cleanup
To avoid AWS charges, destroy all environments:

# Dev environment
cd environments/dev
tofu destroy -auto-approve

# Staging environment
cd ../staging
tofu destroy -auto-approve

# Production environment (if created)
cd ../production
tofu destroy -auto-approve

# Comparison environment (if created)
cd ../comparison
tofu destroy -auto-approve

Key Takeaways

Module Structure: Consistent file organization makes modules maintainable
Versioning: Git tags with semantic versioning enable safe evolution
Local vs Remote: Local for development, remote for consumption
Outputs Matter: Export all useful values for module composition
Documentation: README and inline comments are essential
Community Modules: Can save time but evaluate carefully
Iteration: Modules should evolve with new features while maintaining backward compatibility