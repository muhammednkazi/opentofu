# Provider configuration using variable
provider "aws" {
  region = var.aws_region  # References the aws_region variable
}

# Data source to fetch the latest Ubuntu AMI
# This is dynamic - always gets the newest version
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]  # Canonical's AWS account ID
  
  # Filter criteria to find the right AMI
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group - acts as a virtual firewall
resource "aws_security_group" "web_sg" {
  name        = "${var.project_name}-${var.environment}-web-sg"
  description = "Security group for web server allowing HTTP and SSH"
  
  # Ingress rule for SSH (port 22)
  ingress {
    description = "SSH from allowed CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }
  
  # Ingress rule for HTTP (port 80)
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Open to internet
  }
  
  # Egress rule - allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Merge common tags with resource-specific tags
  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-web-sg"
    }
  )
}

# EC2 Instance
resource "aws_instance" "web_server" {
  # Use the dynamically fetched AMI
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  
  # Associate the security group
  # This creates an implicit dependency
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  
  # User data script - runs on first boot
  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y apache2
              systemctl start apache2
              systemctl enable apache2
              echo "<h1>Hello from OpenTofu!</h1>" > /var/www/html/index.html
              EOF
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-web-server"
    }
  )
}