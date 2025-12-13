# Data Source 1: Query the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# Data Source 2: Get current AWS account information
data "aws_caller_identity" "current" {}

# Data Source 3: Get availability zones in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Data Source 4: Query default VPC
data "aws_vpc" "default" {
  default = true
}

# Data Source 5: Query subnets in default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
