# S3 Bucket for State Storage
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = false # Set to true in production!
  }

  tags = {
    Name        = "OpenTofu State Bucket"
    Description = "Stores OpenTofu state files"
  }
}

# Enable Versioning
resource "aws_s3_bucket_versioning" "terraform_state" {
  count  = var.enable_versioning ? 1 : 0
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  count  = var.enable_encryption ? 1 : 0
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block Public Access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "OpenTofu State Lock Table"
    Description = "Manages state locking for OpenTofu"
  }
}
