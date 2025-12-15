package terraform.tagging

import future.keywords.if

# Test: Resources with all required tags should pass
test_compliant_resource if {
    test_input := {
        "resource_changes": [{
            "type": "aws_instance",
            "address": "aws_instance.compliant",
            "change": {
                "actions": ["create"],
                "after": {
                    "tags": {
                        "Environment": "production",
                        "Owner": "platform-team",
                        "CostCenter": "engineering"
                    }
                }
            }
        }]
    }
    
    violations := deny with input as test_input
    count(violations) == 0
}

# Test: Resource missing tags should fail
test_missing_all_tags if {
    test_input := {
        "resource_changes": [{
            "type": "aws_instance",
            "address": "aws_instance.noncompliant",
            "change": {
                "actions": ["create"],
                "after": {
                    "tags": {}
                }
            }
        }]
    }
    
    violations := deny with input as test_input
    count(violations) == 3  # Three required tags missing
}

# Test: Resource missing one tag should fail with specific message
test_missing_one_tag if {
    test_input := {
        "resource_changes": [{
            "type": "aws_instance",
            "address": "aws_instance.partial",
            "change": {
                "actions": ["create"],
                "after": {
                    "tags": {
                        "Environment": "dev",
                        "Owner": "team"
                    }
                }
            }
        }]
    }
    
    violations := deny with input as test_input
    count(violations) == 1
    
    # Check message contains correct tag name
    some violation in violations
    contains(violation, "CostCenter")
}

# Test: Invalid environment value should fail
test_invalid_environment if {
    test_input := {
        "resource_changes": [{
            "type": "aws_instance",
            "address": "aws_instance.invalid_env",
            "change": {
                "actions": ["create"],
                "after": {
                    "tags": {
                        "Environment": "development",  # Invalid
                        "Owner": "team",
                        "CostCenter": "eng"
                    }
                }
            }
        }]
    }
    
    violations := deny with input as test_input
    count(violations) >= 1
    
    # Check message mentions invalid value
    some violation in violations
    contains(violation, "development")
}

# Test: Exempt resources should not be checked
test_exempt_resources if {
    test_input := {
        "resource_changes": [{
            "type": "random_id",
            "address": "random_id.suffix",
            "change": {
                "actions": ["create"],
                "after": {}
            }
        }]
    }
    
    violations := deny with input as test_input
    count(violations) == 0
}
