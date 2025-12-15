locals {
  # Environment-specific configurations
  environments = {
    dev = {
      instance_type     = "t3.small"
      instance_count    = 1
      vpc_cidr          = "10.0.0.0/16"
      enable_monitoring = false
      volume_size       = 20
    }
    staging = {
      instance_type     = "t3.medium"
      instance_count    = 3
      vpc_cidr          = "10.1.0.0/16"
      enable_monitoring = true
      volume_size       = 30
    }
    prod = {
      instance_type     = "t3.large"
      instance_count    = 3
      vpc_cidr          = "10.2.0.0/16"
      enable_monitoring = true
      volume_size       = 50
    }
  }

  # Get configuration for current workspace
  env = local.environments[terraform.workspace]

  # Validate workspace
  valid_workspaces = ["dev", "staging", "prod"]
  workspace_valid  = contains(local.valid_workspaces, terraform.workspace)
}

# Workspace validation
resource "null_resource" "workspace_check" {
  lifecycle {
    precondition {
      condition     = local.workspace_valid
      error_message = "Invalid workspace '${terraform.workspace}'. Must be one of: ${join(", ", local.valid_workspaces)}"
    }
  }
}
