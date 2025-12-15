variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH (use your IP)"
  type        = string
  default     = "0.0.0.0/0"  # Change this to your IP for security!
}

variable "ami_owner" {
  description = "Owner ID for Ubuntu AMIs"
  type        = string
  default     = "099720109477"  # Canonical
}