# Define an EC2 instance resource
# Syntax: resource "PROVIDER_RESOURCE_TYPE" "LOCAL_NAME"
resource "aws_instance" "firstvm" {
  # AMI (Amazon Machine Image) - the template for the instance
  # This is an Amazon linux image
  ami           = "ami-0d176f79571d18a8f"

  # Instance type determines CPU, memory, and cost
  instance_type = "t2.micro"
  subnet_id     = "subnet-1033165c"


# Tags help identify and organize resources
  tags = {
    Name        = "firstvm"
    Environment = "Development"
    ManagedBy   = "OpenTofu"
  }
}

# Output the public IP address of the created instance
# This will be displayed after 'tofu apply' completes
output "server_public_ip" {
  description = "Public IP address of the web server"
  value       = aws_instance.firstvm.public_ip
}