Lesson 6 - Complex Infrastructure with Dependencies

Goal: Build a complete 3-tier web application infrastructure with database, auto-scaling, and load balancing.

Concepts Covered:

Complex resource dependencies
for_each loops
Dynamic blocks
Local values
Data source chaining
Best practices in real-world scenarios

project/
├── main.tf                 # Main resources
├── variables.tf            # Input variables
├── outputs.tf              # Outputs
├── locals.tf               # Local values
├── data.tf                 # Data sources
├── backend.tf              # Backend configuration
├── terraform.tfvars        # Variable values
└── modules/
    └── vpc/                # VPC module from Use Case 3


# 1. Initialize
tofu init

# 2. Validate
tofu validate

# 3. Format code
tofu fmt -recursive

# 4. Plan with variables
tofu plan \
  -var="db_password=SuperSecurePassword123!" \
  -var="environment=staging"

# 5. Apply
tofu apply \
  -var="db_password=SuperSecurePassword123!" \
  -var="environment=staging"

# 6. Test application
LOAD_BALANCER_URL=$(tofu output -raw load_balancer_url)
curl $LOAD_BALANCER_URL

# 7. Scale up/down
tofu apply \
  -var="desired_capacity=4" \
  -var="db_password=SuperSecurePassword123!"

# 8. View infrastructure graph
tofu graph | dot -Tpng > graph.png

# 9. Destroy when done
tofu destroy \
  -var="db_password=SuperSecurePassword123!"


  Best Practices Demonstrated:

Module Usage: Reusable VPC module
Separation of Concerns: Multiple files (variables, data, locals)
Naming Conventions: Consistent naming with prefixes
Tagging Strategy: Common tags for all resources
Security: Security groups, encryption, private subnets
High Availability: Multi-AZ, auto-scaling, health checks
State Management: Remote backend with locking
Sensitive Data: Marked as sensitive, not in code
Documentation: Comments explaining complex logic
Cost Optimization: Auto-scaling, right-sizing instances

Summary:
You've now learned:

OpenTofu fundamentals (providers, resources, variables, outputs)
Simple single-resource deployments
Multi-resource infrastructures with dependencies
Module creation and usage for reusability
Remote state management and collaboration
Complex real-world infrastructure patterns

Common Commands Reference

# Initialize working directory
tofu init

# Validate configuration
tofu validate

# Format code
tofu fmt

# Preview changes
tofu plan

# Apply changes
tofu apply

# Destroy infrastructure
tofu destroy

# Show current state
tofu show

# List resources in state
tofu state list

# View outputs
tofu output

# View dependency graph
tofu graph

# Import existing resource
tofu import RESOURCE_TYPE.NAME RESOURCE_ID

# Refresh state
tofu refresh

# Taint resource (force recreation)
tofu taint RESOURCE_TYPE.NAME

# Untaint resource
tofu untaint RESOURCE_TYPE.NAME