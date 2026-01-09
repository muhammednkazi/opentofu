# LAB: Migrate to Remote S3 Backend and Manage Concurrent Applies

## Lab Overview


**Scenario:** 
You're a DevOps engineer at a growing startup. Your infrastructure was initially managed by a single developer using local state. Now that the team is expanding, you need to migrate to a remote backend to enable team collaboration and prevent state conflicts.

**What You'll Do:**
1. Deploy infrastructure using local state
2. Create S3 bucket and DynamoDB table for remote state
3. Migrate from local to remote state
4. Test state locking with concurrent operations
5. Practice state manipulation commands (import, move, remove)
6. Handle lock conflicts and recovery scenarios

**Learning Outcomes:**
- Configure and migrate to S3 remote backend
- Implement state locking with DynamoDB
- Safely manipulate state
- Troubleshoot common state issues

---

## Prerequisites

### Required Tools
- OpenTofu CLI (v1.6+): `tofu --version`
- AWS CLI configured: `aws sts get-caller-identity`
- Text editor
- Terminal with multiple tabs/windows (for concurrent testing)

### AWS Permissions Required
- S3: CreateBucket, PutObject, GetObject, ListBucket
- DynamoDB: CreateTable, PutItem, GetItem, DeleteItem
- EC2: CreateVpc, CreateSubnet, RunInstances, DescribeInstances
- IAM: PassRole (if using instance profiles)

## Lab Architecture


┌─────────────────────────────────────────────────────────┐
│                     AWS Cloud                            │
│                                                          │
│  ┌──────────────────────────────────────────┐           │
│  │         State Backend Resources           │           │
│  │  ┌────────────┐      ┌──────────────┐   │           │
│  │  │ S3 Bucket  │      │  DynamoDB    │   │           │
│  │  │  (State)   │      │ (Locking)    │   │           │
│  │  └────────────┘      └──────────────┘   │           │
│  └──────────────────────────────────────────┘           │
│                                                          │
│  ┌──────────────────────────────────────────┐           │
│  │      Application Infrastructure           │           │
│  │  ┌─────────────────────────────────┐     │           │
│  │  │          VPC (10.0.0.0/16)      │     │           │
│  │  │                                  │     │           │
│  │  │  ┌──────────┐   ┌──────────┐   │     │           │
│  │  │  │  Public  │   │  Public  │   │     │           │
│  │  │  │  Subnet  │   │  Subnet  │   │     │           │
│  │  │  │  (AZ-a)  │   │  (AZ-b)  │   │     │           │
│  │  │  └────┬─────┘   └─────┬────┘   │     │           │
│  │  │       │                │        │     │           │
│  │  │   ┌───▼────┐      ┌───▼────┐  │     │           │
│  │  │   │  Web   │      │  Web   │  │     │           │
│  │  │   │ Server │      │ Server │  │     │           │
│  │  │   │  (t3)  │      │  (t3)  │  │     │           │
│  │  │   └────────┘      └────────┘  │     │           │
│  │  │                                │     │           │
│  │  └─────────────────────────────────┘     │           │
│  └──────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────┘


---

## Phase 1: Setup and Local State Deployment

### Important: Directory Navigation

Throughout this lab, you'll work in different directories:


~/tofu-state-lab/              ← Project root
├── local-state/               ← Phase 1, 3-6 (main work)
├── backend-resources/         ← Phase 2 only
└── backend-config.txt         ← Created in Phase 2


**Key Navigation Points:**
- **Phase 1**: Work in `local-state/`
- **Phase 2**: Switch to `backend-resources/`
- **Phase 3-6**: Return to `local-state/`

Each step will clearly indicate which directory to be in!

---

### Step 1: Create Lab Directory Structure


# Create project directory
mkdir -p ~/tofu-state-lab/{local-state,backend-resources,remote-state}
cd ~/tofu-state-lab


### Step 2: Deploy Infrastructure with Local State

Create the initial infrastructure using local state.

**File: local-state/versions.tf**

cd local-state
cat > versions.tf << 'EOF'
terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
EOF


**File: local-state/providers.tf**

cat > providers.tf << 'EOF'
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "OpenTofu-State-Lab"
      Environment = "Development"
      ManagedBy   = "OpenTofu"
    }
  }
}
EOF


**File: local-state/variables.tf**

cat > variables.tf << 'EOF'
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "tofu-state-lab"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}
EOF


**File: local-state/main.tf**

cat > main.tf << 'EOF'
# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${var.availability_zones[count.index]}"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "web" {
  name_description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}
EOF


**File: local-state/data.tf**

cat > data.tf << 'EOF'
# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
EOF


**File: local-state/compute.tf**

cat > compute.tf << 'EOF'
# Web Servers
resource "aws_instance" "web" {
  count                  = 2
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public[count.index].id
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = <<-EOF
              #!/bin/
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Web Server ${count.index + 1}</h1>" > /var/www/html/index.html
              echo "<p>Hostname: $(hostname)</p>" >> /var/www/html/index.html
              echo "<p>Instance ID: $(ec2-metadata --instance-id | cut -d ' ' -f 2)</p>" >> /var/www/html/index.html
              EOF

  tags = {
    Name = "${var.project_name}-web-${count.index + 1}"
  }
}
EOF


**File: local-state/outputs.tf**

cat > outputs.tf << 'EOF'
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "web_server_public_ips" {
  description = "Public IP addresses of web servers"
  value       = aws_instance.web[*].public_ip
}

output "web_server_urls" {
  description = "URLs to access web servers"
  value       = [for ip in aws_instance.web[*].public_ip : "http://${ip}"]
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.web.id
}
EOF


### Step 3: Initialize and Deploy with Local State


# Initialize
tofu init

# Review plan
tofu plan

# Apply configuration
tofu apply -auto-approve


**Expected output:**

Apply complete! Resources: 11 added, 0 changed, 0 destroyed.

Outputs:

vpc_id = "vpc-0abc123def456789"
web_server_public_ips = [
  "54.123.45.67",
  "54.123.45.68",
]
web_server_urls = [
  "http://54.123.45.67",
  "http://54.123.45.68",
]


### Step 4: Verify Local State


# Check state file exists locally
ls -lh terraform.tfstate

# View state file size
du -h terraform.tfstate

# List all resources in state
tofu state list

# Show specific resource
tofu state show aws_vpc.main

# View all outputs
tofu output


**Test web servers:**

# Get URLs and test
curl $(tofu output -json web_server_urls | jq -r '.[0]')
curl $(tofu output -json web_server_urls | jq -r '.[1]')


---

## Phase 2: Create Remote Backend Infrastructure

### Step 5: Create Backend Resources

We'll create the S3 bucket and DynamoDB table that will store our state.

**Important:** We'll create these with a separate OpenTofu configuration to avoid a chicken-and-egg problem.


cd ~/tofu-state-lab/backend-resources


**File: backend-resources/versions.tf**

cat > versions.tf << 'EOF'
terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
EOF


**File: backend-resources/providers.tf**

cat > providers.tf << 'EOF'
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "OpenTofu-State-Backend"
      Environment = "Production"
      ManagedBy   = "OpenTofu"
    }
  }
}
EOF


**File: backend-resources/variables.tf**

cat > variables.tf << 'EOF'
variable "aws_region" {
  description = "AWS region for backend resources"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Name for S3 state bucket (must be globally unique)"
  type        = string
  # Change this to something unique!
  default     = "my-tofu-state-bucket-12345"
}

variable "dynamodb_table_name" {
  description = "Name for DynamoDB lock table"
  type        = string
  default     = "tofu-state-lock"
}

variable "enable_versioning" {
  description = "Enable versioning for state bucket"
  type        = bool
  default     = true
}

variable "enable_encryption" {
  description = "Enable server-side encryption"
  type        = bool
  default     = true
}
EOF


**File: backend-resources/main.tf**

cat > main.tf << 'EOF'
# S3 Bucket for State Storage
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = false  # Set to true in production!
  }

  tags = {
    Name        = "OpenTofu State Bucket"
    Description = "Stores OpenTofu state files"
  }
}

# Enable Versioning
resource "aws_s3_bucket_versioning" "terraform_state" {
  count  = var.enable_versioning ? 1 : 0
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  count  = var.enable_encryption ? 1 : 0
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block Public Access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "OpenTofu State Lock Table"
    Description = "Manages state locking for OpenTofu"
  }
}
EOF


**File: backend-resources/outputs.tf**

cat > outputs.tf << 'EOF'
output "s3_bucket_name" {
  description = "Name of the S3 bucket for state"
  value       = aws_s3_bucket.terraform_state.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.terraform_locks.arn
}

output "backend_config" {
  description = "Backend configuration for use in other projects"
  value = <<-EOT
    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.terraform_state.id}"
        key            = "terraform.tfstate"
        region         = "${var.aws_region}"
        encrypt        = true
        dynamodb_table = "${aws_dynamodb_table.terraform_locks.name}"
      }
    }
  EOT
}
EOF


### Step 6: Deploy Backend Resources


# YOU SHOULD STILL BE IN: ~/tofu-state-lab/backend-resources

# Initialize
tofu init

# Review what will be created
tofu plan

# Create backend resources
tofu apply -auto-approve

# Save the backend configuration output (still in backend-resources directory)
# The ../ saves it to the parent directory (~/tofu-state-lab/)
tofu output -raw backend_config > ../backend-config.txt

# View the backend configuration
cat ../backend-config.txt


**Directory Context:**
- You're currently in: `~/tofu-state-lab/backend-resources`
- The output file is saved to: `~/tofu-state-lab/backend-config.txt`
- This makes it accessible from the project root

**Important:** Note your bucket name from the output - you'll need it for migration!

---

## Phase 3: Migrate to Remote State

### Step 7: Add Backend Configuration


# CHANGE DIRECTORY to local-state
cd ~/tofu-state-lab/local-state

# Verify you're in the right directory
pwd
# Should show: /home/<user>/tofu-state-lab/local-state


Add the backend configuration to your `versions.tf`:


# Backup original versions.tf
cp versions.tf versions.tf.backup

# Update versions.tf with backend config
cat > versions.tf << 'EOF'
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
    bucket         = "my-tofu-state-bucket-12345"  # Change to your bucket name!
    key            = "lab/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "tofu-state-lock"
  }
}
EOF


**IMPORTANT:** Replace `my-tofu-state-bucket-12345` with your actual bucket name!

### Step 8: Perform State Migration


# Reinitialize to migrate state
tofu init -migrate-state


**Expected prompts:**

Initializing the backend...
Do you want to copy existing state to the new backend?
  Pre-existing state was found while migrating the previous "local" backend to the
  newly configured "s3" backend. No existing state was found in the newly
  configured "s3" backend. Do you want to copy this state to the new "s3"
  backend? Enter "yes" to copy and "no" to start with an empty state.

  Enter a value: yes

Successfully configured the backend "s3"! OpenTofu will automatically
use this backend unless the backend configuration changes.


Type **yes** to migrate.

### Step 9: Verify Migration


# Verify no changes needed (state should match)
tofu plan

# List resources (should show same resources)
tofu state list

# Check S3 bucket
aws s3 ls s3://my-tofu-state-bucket-12345/lab/

# Download and inspect remote state
aws s3 cp s3://my-tofu-state-bucket-12345/lab/terraform.tfstate - | jq '.version'


**Verify local state backup exists:**

ls -lh terraform.tfstate.backup


### Step 10: Test State Versioning


# Make a small change
tofu apply -auto-approve -var="project_name=tofu-state-lab-v2"

# Check S3 versions
aws s3api list-object-versions \
  --bucket my-tofu-state-bucket-12345 \
  --prefix lab/terraform.tfstate \
  --query 'Versions[*].[VersionId,LastModified]' \
  --output table


You should see multiple versions!

---

## Phase 4: Test State Locking

### Step 11: Test Concurrent Operations

Open **two terminal windows** side by side.

**Terminal 1:**

cd ~/tofu-state-lab/local-state

# Start a long-running apply with a sleep in user_data
tofu apply -auto-approve


**Terminal 2 (start within 5 seconds of Terminal 1):**

cd ~/tofu-state-lab/local-state

# Try to run concurrent apply
tofu apply


**Expected result in Terminal 2:**

Error: Error acquiring the state lock

Error message: ConditionalCheckFailedException: The conditional request failed
Lock Info:
  ID:        a1b2c3d4-e5f6-7890-abcd-ef1234567890
  Path:      my-tofu-state-bucket-12345/lab/terraform.tfstate
  Operation: OperationTypeApply
  Who:       user@hostname
  Version:   1.6.0
  Created:   2024-01-15 14:30:00.123456 UTC
  Info:      

OpenTofu acquires a state lock to protect the state from being written
by multiple users at the same time. Please resolve the issue above and try
again. For most commands, you can disable locking with the "-lock=false"
flag, but this is not recommended.


This is **expected behavior** - state locking is working!

### Step 12: View Lock in DynamoDB

While Terminal 1 is still running:


# In a third terminal
aws dynamodb scan \
  --table-name tofu-state-lock \
  --output json | jq


You should see the lock record with details about who holds the lock.

### Step 13: Force Unlock (Recovery Scenario)

**ONLY do this if your apply actually crashed or was interrupted!**

For demonstration, cancel Terminal 1's apply (Ctrl+C), then:


# Get the lock ID from the error message
tofu force-unlock <LOCK_ID>

# Example:
# tofu force-unlock a1b2c3d4-e5f6-7890-abcd-ef1234567890


---

## Phase 5: State Manipulation Commands

### Step 14: Practice Import Command

Let's manually create a resource and import it.

**Create a Security Group manually:**

# Create SG via AWS CLI
SG_ID=$(aws ec2 create-security-group \
  --group-name manually-created-sg \
  --description "Manually created for import demo" \
  --vpc-id $(tofu output -raw vpc_id) \
  --query 'GroupId' \
  --output text)

echo "Created Security Group: $SG_ID"


**Add resource block to main.tf:**

cat >> main.tf << 'EOF'

# Imported Security Group
resource "aws_security_group" "imported" {
  name        = "manually-created-sg"
  description = "Manually created for import demo"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "imported-sg"
  }
}
EOF


**Import the resource:**

tofu import aws_security_group.imported $SG_ID


**Verify import:**

tofu state show aws_security_group.imported
tofu plan  # Should show no changes if configuration matches


### Step 15: Practice State Move

**Rename a resource in state:**

# List current resources
tofu state list | grep aws_instance

# Move instance
tofu state mv 'aws_instance.web[0]' 'aws_instance.web_server_1'

# Verify move
tofu state list | grep web_server


**Update configuration to match:**

# You'd need to update compute.tf to reflect the new name
# For lab purposes, let's move it back
tofu state mv 'aws_instance.web_server_1' 'aws_instance.web[0]'


### Step 16: Practice State Remove

**Remove imported SG from state (without destroying):**

# Remove from state
tofu state rm aws_security_group.imported

# Verify it's gone from state
tofu state list | grep imported

# Verify resource still exists in AWS
aws ec2 describe-security-groups \
  --group-ids $SG_ID \
  --query 'SecurityGroups[0].GroupName' \
  --output text


**Clean up manual resource:**

aws ec2 delete-security-group --group-id $SG_ID


### Step 17: State Backup and Recovery

**Pull state for backup:**

# Create backup directory
mkdir -p backups

# Pull current state
tofu state pull > backups/state-$(date +%Y%m%d-%H%M%S).json

# Verify backup
ls -lh backups/


**Simulate recovery scenario:**

# View current state serial number
tofu state pull | jq '.serial'

# Make a change
tofu apply -auto-approve -var="project_name=recovery-test"

# View new serial number
tofu state pull | jq '.serial'

# If needed, you could restore from backup (DANGEROUS - for demo only)
# tofu state push backups/state-XXXXXXXX.json


---

## Phase 6: Testing and Verification

### Step 18: Comprehensive Testing

**Test 1: Remote state is accessible**

# Clear local state files
rm -f terraform.tfstate*

# Re-initialize (should pull from remote)
tofu init

# Plan should show no changes
tofu plan


**Test 2: State locking prevents issues**

# In one terminal, start a refresh
tofu refresh &

# In another terminal, immediately try to apply
tofu apply
# Should get lock error


**Test 3: State versioning works**

# List all state versions
aws s3api list-object-versions \
  --bucket my-tofu-state-bucket-12345 \
  --prefix lab/ \
  --output table


**Test 4: Infrastructure still works**

# Get web server URLs
tofu output -json web_server_urls | jq -r '.[]' | while read url; do
  echo "Testing $url"
  curl -s $url | grep -i "web server"
done


---

## Cleanup

### Step 19: Destroy Lab Infrastructure


# Destroy application infrastructure
cd ~/tofu-state-lab/local-state
tofu destroy -auto-approve

# Verify destruction
tofu state list  # Should be empty

# Destroy backend resources
cd ~/tofu-state-lab/backend-resources
tofu destroy -auto-approve

# Remove lab directory
cd ~
rm -rf ~/tofu-state-lab


---

## Lab Checklist

Use this checklist to verify you've completed all objectives:

- [ ] Deployed infrastructure with local state
- [ ] Created S3 bucket for state storage
- [ ] Created DynamoDB table for state locking
- [ ] Successfully migrated from local to remote state
- [ ] Verified state versioning in S3
- [ ] Tested concurrent apply operations (lock worked)
- [ ] Viewed lock information in DynamoDB
- [ ] Practiced force-unlock command
- [ ] Imported existing resource into state
- [ ] Used state mv to rename resources
- [ ] Used state rm to remove resources
- [ ] Created state backups with state pull
- [ ] Verified remote state accessibility
- [ ] Cleaned up all resources

---

## Key Takeaways

1. **Migration is Safe**: OpenTofu's migration process preserves state integrity
2. **Locking is Critical**: Prevents corruption from concurrent operations
3. **Versioning Saves You**: Can recover from mistakes
4. **State Commands are Powerful**: But use with caution
5. **Remote State Enables Teams**: Essential for collaboration
6. **Always Backup**: Before any state manipulation


## What's Next?

After completing this lab, you should:
1. Review your organization's state management strategy
2. Implement remote state for production workloads
3. Set up proper IAM policies for state access
4. Configure backend configurations per environment
5. Establish state backup procedures
6. Document state recovery procedures

**Advanced Topics to Explore:**
- Workspaces for environment management
- State encryption with KMS
- Cross-account state access
- Automated state backup workflows
- State import automation
- Multi-backend strategies