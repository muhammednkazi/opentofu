package terraform.cost

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Maximum instance sizes by environment
max_instance_size := {
    "dev": ["nano", "micro", "small"],
    "staging": ["small", "medium", "large"],
    "production": ["medium", "large", "xlarge", "2xlarge"]
}

# Get environment from tags
get_environment(resource) := env if {
    tags := object.get(resource.change.after, "tags", {})
    env := object.get(tags, "Environment", "dev")  # Default to dev
}

# Extract size from instance type (e.g., "t3.large" -> "large")
get_instance_size(instance_type) := size if {
    parts := split(instance_type, ".")
    count(parts) == 2
    size := parts[1]
}

# Check if instance size is allowed for environment
is_allowed_size(instance_type, environment) if {
    size := get_instance_size(instance_type)
    allowed := max_instance_size[environment]
    allowed[_] == size
}

# Deny oversized instances
deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_instance"
    action := resource.change.actions[_]
    action != "delete"
    
    instance_type := resource.change.after.instance_type
    environment := get_environment(resource)
    
    not is_allowed_size(instance_type, environment)
    
    size := get_instance_size(instance_type)
    allowed := max_instance_size[environment]
    
    msg := sprintf(
        "❌ COST: Instance '%s' type '%s' (size: %s) exceeds maximum for environment '%s'. Allowed sizes: %v",
        [resource.address, instance_type, size, environment, allowed]
    )
}

# Deny expensive RDS instance classes
deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_db_instance"
    action := resource.change.actions[_]
    action != "delete"
    
    instance_class := resource.change.after.instance_class
    environment := get_environment(resource)
    
    # For dev environment, only allow t3 instances
    environment == "dev"
    not startswith(instance_class, "db.t3")
    
    msg := sprintf(
        "❌ COST: RDS instance '%s' class '%s' not allowed in dev environment. Use db.t3.* instances.",
        [resource.address, instance_class]
    )
}

# Warn about large storage allocations
warn contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_db_instance"
    action := resource.change.actions[_]
    action != "delete"
    
    allocated_storage := resource.change.after.allocated_storage
    allocated_storage > 100
    
    environment := get_environment(resource)
    environment != "production"
    
    msg := sprintf(
        "⚠️  COST: RDS instance '%s' has %d GB allocated storage in non-production. Consider reducing for cost savings.",
        [resource.address, allocated_storage]
    )
}

# Warn about gp3 volumes (recommend cost optimization)
warn contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_instance"
    action := resource.change.actions[_]
    action != "delete"
    
    root_block := resource.change.after.root_block_device[0]
    volume_type := root_block.volume_type
    volume_type != "gp3"
    
    msg := sprintf(
        "⚠️  COST: Instance '%s' using volume type '%s'. Consider gp3 for better cost efficiency.",
        [resource.address, volume_type]
    )
}
