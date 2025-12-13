provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "OpenTofu-State-Lab"
      Environment = "Development"
      ManagedBy   = "OpenTofu"
    }
  }
}
