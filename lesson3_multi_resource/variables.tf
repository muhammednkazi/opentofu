# Variable definitions file
# Separating variables improves organization

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
  
  # Validation ensures only allowed values are used
  validation {
    condition     = contains(["t2.micro", "t2.small", "t2.medium"], var.instance_type)
    error_message = "Instance type must be t2.micro, t2.small, or t2.medium."
  }
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into instance"
  type        = string
  default     = "0.0.0.0/0"  # Warning: Open to world - use your IP in production
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "training"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "OpenTofu"
    Project   = "Training"
  }
}