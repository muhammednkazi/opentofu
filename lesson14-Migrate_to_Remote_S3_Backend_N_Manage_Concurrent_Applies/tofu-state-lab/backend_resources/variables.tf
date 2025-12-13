variable "aws_region" {
  description = "AWS region for backend resources"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Name for S3 state bucket (must be globally unique)"
  type        = string
  # Change this to something unique!
  default     = "my-tofu-state-bucket-12345"
}

variable "dynamodb_table_name" {
  description = "Name for DynamoDB lock table"
  type        = string
  default     = "tofu-state-lock"
}

variable "enable_versioning" {
  description = "Enable versioning for state bucket"
  type        = bool
  default     = true
}

variable "enable_encryption" {
  description = "Enable server-side encryption"
  type        = bool
  default     = true
}