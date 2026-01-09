Deploy to Development

# Initialize
tofu init

# Create dev workspace (default workspace also works)
tofu workspace new dev

# Verify workspace
tofu workspace show
# Output: dev

# Plan deployment
tofu plan

# Apply
tofu apply

# Save SSH key
tofu output -raw ssh_private_key > dev-key.pem
chmod 600 dev-key.pem

# Get web URLs
tofu output web_urls

# Test the deployment
# Visit the URLs in your browser
# You should see: 1 instance in dev environment

##############################################################

 Deploy to Staging

# Create staging workspace
tofu workspace new staging

# Verify workspace
tofu workspace show
# Output: staging

# Apply (note: different CIDR, more instances)
tofu apply

# Check outputs
tofu output environment_config
# Should show: 2 instances, t3.medium

# Get URLs
tofu output web_urls

# Test staging
# Visit URLs - you should see: Instance 1 of 2, Instance 2 of 2


###########################################################################

Deploy to Production

# Create prod workspace
tofu workspace new prod

# Verify
tofu workspace show
# Output: prod

# Review plan carefully (production!)
tofu plan

# Apply
tofu apply

# Check outputs
tofu output environment_config
# Should show: 3 instances, t3.large, monitoring enabled

# List all workspaces
tofu workspace list
# Output:
#   dev
#   staging
# * prod

#################################################################

Explore Workspace Isolation


# Show state in prod workspace
tofu state list
# Shows 3 instances + associated resources

# Switch to dev
tofu workspace select dev

# Show state in dev workspace
tofu state list
# Shows only 1 instance + associated resources

# List all workspaces and their resources
for ws in dev staging prod; do
  echo "=== Workspace: $ws ==="
  tofu workspace select $ws
  tofu state list | grep aws_instance.web
done

##################################################################

Verify Workspace Functionality

# In dev workspace
tofu workspace select dev
tofu output vpc_id
# Note the VPC ID (should start with vpc-)

# In staging workspace
tofu workspace select staging
tofu output vpc_id
# Note: Different VPC ID!

# In prod workspace
tofu workspace select prod
tofu output vpc_id
# Note: Yet another different VPC ID!

# Verify CloudWatch alarms only in prod
aws cloudwatch describe-alarms --alarm-name-prefix "prod-web"
# Should show alarms

aws cloudwatch describe-alarms --alarm-name-prefix "dev-web"
# Should show no alarms


####################################################################### 

Make Changes to Specific Environment

# Modify only staging
tofu workspace select staging

# Edit locals.tf to change staging instance_count to 3
# Then apply
tofu plan
tofu apply

# Verify other environments unchanged
tofu workspace select dev
tofu plan
# Should show: No changes

tofu workspace select prod
tofu plan
# Should show: No changes

######################################################################

# Destroy in each workspace
for ws in dev staging prod; do
  echo "Destroying $ws environment..."
  tofu workspace select $ws
  tofu destroy -auto-approve
done

# Verify all destroyed
tofu workspace select dev
tofu state list
# Should be empty

# Optional: Delete workspaces
tofu workspace select default
tofu workspace delete dev
tofu workspace delete staging
tofu workspace delete prod

Summary
What You Learned:
✅ Created and managed multiple workspaces
✅ Used terraform.workspace for environment-specific config
✅ Deployed different infrastructure per environment
✅ Verified workspace state isolation
✅ Managed environment-specific resources (CloudWatch alarms in prod only)
Key Observations:

Same code, different results per workspace
Complete state isolation between workspaces
Easy environment creation/destruction
Workspace interpolation enables dynamic configuration

Common Issues:

Forgetting which workspace you're in
Applying wrong configuration to wrong workspace
Not verifying workspace before running apply


