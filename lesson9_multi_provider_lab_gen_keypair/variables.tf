variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

#variable "key_pair_name" {
#  description = "Name of the SSH key pair to use for the instance"
#  type        = string
#  default     = ""
#}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH"
  type        = string
  default     = "0.0.0.0/0" # Restrict this in production!
}

variable "root_volume_size" {
  description = "Size of root volume in GB"
  type        = number
  default     = 30
}
