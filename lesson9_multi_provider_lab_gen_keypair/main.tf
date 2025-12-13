# Resource 1: Random suffix for unique naming
resource "random_id" "server_suffix" {
  byte_length = 4
}

# Resource 2: Random password for demonstration
resource "random_password" "db_password" {
  length  = 16
  special = true
}

# Resource 3: Security Group (demonstrates implicit dependencies)
resource "aws_security_group" "web_server_sg" {
  name_prefix = "web-server-${random_id.server_suffix.hex}-"
  description = "Security group for web server with SSH and HTTP access"
  vpc_id      = data.aws_vpc.default.id

  # Ingress rule: SSH
  ingress {
    description = "SSH from specified CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # Ingress rule: HTTP
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress rule: Allow all outbound
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-server-sg-${random_id.server_suffix.hex}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Resource 4: EC2 Instance (demonstrates multiple dependency types)
resource "aws_instance" "web_server" {
  # Dynamic AMI from data source
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  #Key pair name
  key_name = aws_key_pair.web_server_key.key_name

  # Implicit dependency on security group
  vpc_security_group_ids = [aws_security_group.web_server_sg.id]

  # Root volume configuration
  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  # User data with random password demonstration
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              
              # Create a simple web page
              cat > /var/www/html/index.html <<HTML
              <html>
              <head><title>Multi-Provider Lab</title></head>
              <body>
                <h1>OpenTofu Multi-Provider Lab</h1>
                <p>Server ID: ${random_id.server_suffix.hex}</p>
                <p>Instance: $(hostname)</p>
                <p>Region: ${var.aws_region}</p>
                <p>Environment: ${var.environment}</p>
              </body>
              </html>
              HTML
              
              # Store random password (for demonstration only!)
              echo "Demo Password: ${random_password.db_password.result}" > /tmp/demo_password.txt
              chmod 600 /tmp/demo_password.txt
              EOF

  tags = {
    Name = "web-server-${random_id.server_suffix.hex}"
  }

  # Explicit dependency example
  # In real scenarios, this might be an IAM role or S3 bucket
  depends_on = [
    aws_security_group.web_server_sg
  ]
}

# Resource 5: Elastic IP (demonstrates explicit dependency)
resource "aws_eip" "web_server_eip" {
  instance = aws_instance.web_server.id
  domain   = "vpc"

  tags = {
    Name = "web-server-eip-${random_id.server_suffix.hex}"
  }

  # Explicit dependency: Wait for instance to be fully created
  depends_on = [
    aws_instance.web_server
  ]
}
