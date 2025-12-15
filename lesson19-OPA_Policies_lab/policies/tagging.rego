package terraform.tagging

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Required tags for all resources
required_tags := ["Environment", "Owner", "CostCenter"]

# Resources exempt from tagging requirements
tagging_exceptions := {
    "aws_security_group",
    "aws_db_subnet_group",
    "random_id",
    "random_password"
}

# Get all AWS resources being created or modified
aws_resources contains resource if {
    resource := input.resource_changes[_]
    startswith(resource.type, "aws_")
    action := resource.change.actions[_]
    action != "delete"
}

# Get resources that should have tags
taggable_resources contains resource if {
    resource := aws_resources[_]
    not tagging_exceptions[resource.type]
}

# Check for missing required tags
deny contains msg if {
    resource := taggable_resources[_]
    tags := object.get(resource.change.after, "tags", {})
    
    required_tag := required_tags[_]
    not tags[required_tag]
    
    msg := sprintf(
        "❌ TAGGING: Resource '%s' missing required tag '%s'. Required tags: %v",
        [resource.address, required_tag, required_tags]
    )
}

# Check for invalid Environment tag values
deny contains msg if {
    resource := taggable_resources[_]
    tags := object.get(resource.change.after, "tags", {})
    
    env := tags.Environment
    allowed_envs := {"dev", "staging", "production"}
    not allowed_envs[env]
    
    msg := sprintf(
        "❌ TAGGING: Resource '%s' has invalid Environment tag '%s'. Must be one of: %v",
        [resource.address, env, allowed_envs]
    )
}

# Warn about recommended tags
warn contains msg if {
    resource := taggable_resources[_]
    tags := object.get(resource.change.after, "tags", {})
    
    recommended_tags := ["Description", "Project"]
    recommended_tag := recommended_tags[_]
    not tags[recommended_tag]
    
    msg := sprintf(
        "⚠️  TAGGING: Resource '%s' missing recommended tag '%s'",
        [resource.address, recommended_tag]
    )
}
