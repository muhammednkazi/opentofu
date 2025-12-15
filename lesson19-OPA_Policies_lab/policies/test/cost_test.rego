package terraform.cost

import future.keywords.if

# Test: Allowed instance size should pass
test_allowed_instance_size if {
    test_input := {
        "resource_changes": [{
            "type": "aws_instance",
            "address": "aws_instance.dev",
            "change": {
                "actions": ["create"],
                "after": {
                    "instance_type": "t3.micro",
                    "tags": {
                        "Environment": "dev"
                    }
                }
            }
        }]
    }
    
    violations := deny with input as test_input
    count(violations) == 0
}

# Test: Oversized instance should fail
test_oversized_instance if {
    test_input := {
        "resource_changes": [{
            "type": "aws_instance",
            "address": "aws_instance.dev",
            "change": {
                "actions": ["create"],
                "after": {
                    "instance_type": "t3.xlarge",
                    "tags": {
                        "Environment": "dev"
                    }
                }
            }
        }]
    }
    
    violations := deny with input as test_input
    count(violations) >= 1
}

# Test: Production can use larger sizes
test_production_large_instance if {
    test_input := {
        "resource_changes": [{
            "type": "aws_instance",
            "address": "aws_instance.prod",
            "change": {
                "actions": ["create"],
                "after": {
                    "instance_type": "t3.xlarge",
                    "tags": {
                        "Environment": "production"
                    }
                }
            }
        }]
    }
    
    violations := deny with input as test_input
    count(violations) == 0
}

