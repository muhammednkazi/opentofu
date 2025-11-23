# Backend configuration for remote state storage
# This file should be committed to version control

terraform {
  # Backend type and configuration
  backend "s3" {
    # S3 bucket for state file storage
    bucket = "gitss-tofu-state"
    
    # Path within bucket (allows multiple projects)
    key = "projects/training/terraform.tfstate"
    
    # AWS region where bucket exists
    region = "ap-south-1"
    
    # DynamoDB table for state locking
    # Prevents concurrent modifications
    dynamodb_table = "tofu-state-lock"
    
    # Server-side encryption
    encrypt = true
    
    # Optional: Use specific AWS profile
    # profile = "terraform"
  }
  
  # Required provider versions
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Required OpenTofu version
  required_version = ">= 1.6.0"
}