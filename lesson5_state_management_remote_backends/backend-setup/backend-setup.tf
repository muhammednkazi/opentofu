# This file creates the backend infrastructure
# Run this BEFORE configuring backend in main infrastructure

provider "aws" {
  region = "ap-south-1"
}

# S3 Bucket for state storage
resource "aws_s3_bucket" "tofu_state" {
  bucket = "gitss-tofu-state"
  
  tags = {
    Name        = "OpenTofu State Bucket"
    Purpose     = "Remote state storage"
    ManagedBy   = "OpenTofu"
  }
}

# Enable versioning for state file history
resource "aws_s3_bucket_versioning" "tofu_state" {
  bucket = aws_s3_bucket.tofu_state.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "tofu_state" {
  bucket = aws_s3_bucket.tofu_state.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "tofu_state" {
  bucket = aws_s3_bucket.tofu_state.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "tofu_locks" {
  name         = "tofu-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"  # String type
  }
  
  tags = {
    Name        = "OpenTofu State Lock Table"
    Purpose     = "State locking"
    ManagedBy   = "OpenTofu"
  }
}

# Outputs for verification
output "s3_bucket_name" {
  value = aws_s3_bucket.tofu_state.id
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.tofu_locks.name
}