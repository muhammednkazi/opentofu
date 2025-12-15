# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  # ⚠️ VIOLATION: Missing required tags
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  # ⚠️ VIOLATION: Missing Environment tag
  tags = {
    Name  = "${var.project_name}-public-subnet"
    Owner = "platform-team"
  }
}

# S3 Bucket - Public Website
resource "aws_s3_bucket" "public_website" {
  bucket = "${var.project_name}-public-website-${random_id.suffix.hex}"

  # ⚠️ VIOLATION: Missing encryption
  # ⚠️ VIOLATION: Missing tags
  tags = {
    Name = "public-website"
  }
}

resource "aws_s3_bucket_acl" "public_website" {
  bucket = aws_s3_bucket.public_website.id
  # ⚠️ VIOLATION: Public ACL
  acl = "public-read"
}

# S3 Bucket - Private Data
resource "aws_s3_bucket" "private_data" {
  bucket = "${var.project_name}-data-${random_id.suffix.hex}"

  tags = {
    Name        = "${var.project_name}-data"
    Environment = var.environment
    Owner       = "data-team"
    CostCenter  = "engineering"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "private_data" {
  bucket = aws_s3_bucket.private_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# EC2 Instance - Development
resource "aws_instance" "dev_server" {
  ami = data.aws_ami.ubuntu.id
  # ⚠️ VIOLATION: Instance type too large for dev
  instance_type = "t3.xlarge"
  subnet_id     = aws_subnet.public.id

  # ⚠️ VIOLATION: Missing encryption for root volume
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    # encrypted   = true  # Missing!
  }

  tags = {
    Name        = "${var.project_name}-dev-server"
    Environment = var.environment
    Owner       = "dev-team"
    CostCenter  = "engineering"
  }
}

# EC2 Instance - Production
resource "aws_instance" "prod_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.large"
  subnet_id     = aws_subnet.public.id

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
    encrypted   = true
  }

  # ✅ COMPLIANT: All required tags
  tags = {
    Name        = "${var.project_name}-prod-server"
    Environment = "production"
    Owner       = "platform-team"
    CostCenter  = "engineering"
  }
}

# RDS Database
resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-db"
  engine         = "postgres"
  engine_version = "15.3"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100

  db_name  = "appdb"
  username = "admin"
  password = random_password.db_password.result

  # ⚠️ VIOLATION: Encryption not enabled
  storage_encrypted = false

  # ⚠️ VIOLATION: Publicly accessible
  publicly_accessible = true

  skip_final_snapshot = true

  vpc_security_group_ids = [aws_security_group.db.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  # ⚠️ VIOLATION: Missing Owner tag
  tags = {
    Name        = "${var.project_name}-db"
    Environment = var.environment
    CostCenter  = "engineering"
  }
}

# Supporting Resources
resource "random_id" "suffix" {
  byte_length = 4
}

resource "random_password" "db_password" {
  length  = 16
  special = true
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "Database security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-db-sg"
    Environment = var.environment
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [aws_subnet.public.id]

  tags = {
    Name        = "${var.project_name}-db-subnet-group"
    Environment = var.environment
  }
}
