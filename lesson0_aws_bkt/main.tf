# Make a random 6-char suffix to ensure global bucket name uniqueness
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# S3 bucket with a stable prefix + random suffix
resource "aws_s3_bucket" "demo" {
  bucket = "jp-tofu-demo-${random_string.suffix.result}"
}

# Optional: enable bucket versioning
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.demo.id
  versioning_configuration {
    status = "Enabled"
  }
}

output "bucket_name" {
  value = aws_s3_bucket.demo.bucket
}
