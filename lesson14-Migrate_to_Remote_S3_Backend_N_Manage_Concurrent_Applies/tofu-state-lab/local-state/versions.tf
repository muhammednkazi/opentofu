terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote backend configuration
  backend "s3" {
    bucket         = "my-tofu-state-bucket-12345" # Change to your bucket name!
    key            = "lab/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "tofu-state-lock"
  }
}
