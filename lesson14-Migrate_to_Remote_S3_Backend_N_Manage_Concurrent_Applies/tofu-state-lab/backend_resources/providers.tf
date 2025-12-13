provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "OpenTofu-State-Backend"
      Environment = "Production"
      ManagedBy   = "OpenTofu"
    }
  }
}
