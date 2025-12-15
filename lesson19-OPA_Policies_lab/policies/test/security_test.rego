package terraform.security

import future.keywords.if

# Test: Encrypted S3 bucket should pass
test_encrypted_s3_bucket if {
    test_input := {
        "resource_changes": [
            {
                "type": "aws_s3_bucket",
                "address": "aws_s3_bucket.data",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "id": "my-bucket"
                    }
                }
            },
            {
                "type": "aws_s3_bucket_server_side_encryption_configuration",
                "address": "aws_s3_bucket_server_side_encryption_configuration.data",
                "change": {
                    "actions": ["create"],
                    "after": {
                        "bucket": "my-bucket",
                        "rule": [{
                            "apply_server_side_encryption_by_default": [{
                                "sse_algorithm": "AES256"
                            }]
                        }]
                    }
                }
            }
        ]
    }
    
    violations := deny with input as test_input
    count(violations) == 0
}

# Test: Unencrypted S3 bucket should fail
test_unencrypted_s3_bucket if {
    test_input := {
        "resource_changes": [{
            "type": "aws_s3_bucket",
            "address": "aws_s3_bucket.data",
            "change": {
                "actions": ["create"],
                "after": {
                    "id": "my-bucket"
                }
            }
        }]
    }
    
    violations := deny with input as test_input
    count(violations) > 0
}

# Test: Public S3 ACL should fail
test_public_s3_acl if {
    test_input := {
        "resource_changes": [{
            "type": "aws_s3_bucket_acl",
            "address": "aws_s3_bucket_acl.public",
            "change": {
                "actions": ["create"],
                "after": {
                    "acl": "public-read"
                }
            }
        }]
    }
    
    violations := deny with input as test_input
    count(violations) >= 1
}

# Test: Encrypted EC2 instance should pass
test_encrypted_ec2 if {
    test_input := {
        "resource_changes": [{
            "type": "aws_instance",
            "address": "aws_instance.web",
            "change": {
                "actions": ["create"],
                "after": {
                    "root_block_device": [{
                        "encrypted": true
                    }]
                }
            }
        }]
    }
    
    violations := deny with input as test_input
    count(violations) == 0
}

# Test: Unencrypted EC2 instance should fail
test_unencrypted_ec2 if {
    test_input := {
        "resource_changes": [{
            "type": "aws_instance",
            "address": "aws_instance.web",
            "change": {
                "actions": ["create"],
                "after": {
                    "root_block_device": [{
                        "encrypted": false
                    }]
                }
            }
        }]
    }
    
    violations := deny with input as test_input
    count(violations) >= 1
}

