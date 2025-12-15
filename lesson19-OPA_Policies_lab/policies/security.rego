package terraform.security

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# ==================== S3 Security ====================

# Deny S3 buckets without encryption
deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket"
    is_create_or_update(resource)
    
    # Check if encryption configuration exists
    bucket_id := resource.change.after.id
    not has_encryption_config(bucket_id)
    
    msg := sprintf(
        "❌ SECURITY: S3 bucket '%s' must have encryption enabled. Add aws_s3_bucket_server_side_encryption_configuration resource.",
        [resource.address]
    )
}

has_encryption_config(bucket_id) if {
    some resource in input.resource_changes
    resource.type == "aws_s3_bucket_server_side_encryption_configuration"
    resource.change.after.bucket == bucket_id
}

# Deny public S3 bucket ACLs
deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket_acl"
    is_create_or_update(resource)
    
    acl := resource.change.after.acl
    public_acls := {"public-read", "public-read-write", "authenticated-read"}
    public_acls[acl]
    
    msg := sprintf(
        "❌ SECURITY: S3 bucket ACL '%s' uses public ACL '%s'. Use private ACLs only.",
        [resource.address, acl]
    )
}

# ==================== EC2 Security ====================

# Deny EC2 instances without encrypted root volumes
deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_instance"
    is_create_or_update(resource)
    
    root_block := resource.change.after.root_block_device[0]
    not root_block.encrypted == true
    
    msg := sprintf(
        "❌ SECURITY: EC2 instance '%s' root volume must be encrypted. Set root_block_device.encrypted = true",
        [resource.address]
    )
}

# Warn about instances in public subnets
warn contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_instance"
    is_create_or_update(resource)
    
    subnet := resource.change.after.subnet_id
    is_public_subnet(subnet)
    
    msg := sprintf(
        "⚠️  SECURITY: EC2 instance '%s' is in a public subnet. Consider using private subnets for better security.",
        [resource.address]
    )
}

is_public_subnet(subnet_id) if {
    some resource in input.resource_changes
    resource.type == "aws_subnet"
    resource.change.after.id == subnet_id
    resource.change.after.map_public_ip_on_launch == true
}

# ==================== RDS Security ====================

# Deny unencrypted RDS instances
deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_db_instance"
    is_create_or_update(resource)
    
    not resource.change.after.storage_encrypted == true
    
    msg := sprintf(
        "❌ SECURITY: RDS instance '%s' must have storage encryption enabled. Set storage_encrypted = true",
        [resource.address]
    )
}

# Deny publicly accessible RDS instances
deny contains msg if {
    resource := input.resource_changes[_]
    resource.type == "aws_db_instance"
    is_create_or_update(resource)
    
    resource.change.after.publicly_accessible == true
    
    msg := sprintf(
        "❌ SECURITY: RDS instance '%s' must not be publicly accessible. Set publicly_accessible = false",
        [resource.address]
    )
}

# ==================== Helper Functions ====================

is_create_or_update(resource) if {
    action := resource.change.actions[_]
    action != "delete"
}
