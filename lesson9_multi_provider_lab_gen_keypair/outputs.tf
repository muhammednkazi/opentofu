# Output 1: Data source information
output "ami_information" {
  description = "Details about the AMI used"
  value = {
    ami_id        = data.aws_ami.amazon_linux_2023.id
    ami_name      = data.aws_ami.amazon_linux_2023.name
    creation_date = data.aws_ami.amazon_linux_2023.creation_date
    architecture  = data.aws_ami.amazon_linux_2023.architecture
  }
}

output "account_information" {
  description = "Current AWS account details"
  value = {
    account_id = data.aws_caller_identity.current.account_id
    user_id    = data.aws_caller_identity.current.user_id
    arn        = data.aws_caller_identity.current.arn
  }
}

output "vpc_information" {
  description = "Default VPC information"
  value = {
    vpc_id     = data.aws_vpc.default.id
    cidr_block = data.aws_vpc.default.cidr_block
  }
}

output "availability_zones" {
  description = "Available AZs in the region"
  value       = data.aws_availability_zones.available.names
}

# Output 2: Random provider results
output "server_suffix" {
  description = "Random suffix used for naming"
  value       = random_id.server_suffix.hex
}

output "generated_password" {
  description = "Generated password (sensitive)"
  value       = random_password.db_password.result
  sensitive   = true
}

# Output 3: EC2 instance information
output "instance_information" {
  description = "Web server instance details"
  value = {
    instance_id       = aws_instance.web_server.id
    instance_type     = aws_instance.web_server.instance_type
    private_ip        = aws_instance.web_server.private_ip
    public_ip         = aws_eip.web_server_eip.public_ip
    availability_zone = aws_instance.web_server.availability_zone
  }
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.web_server_sg.id
}

# Output 4: Connection information
output "connection_instructions" {
  description = "How to connect to the instance"
  value       = <<-EOT
    Web Server URL: http://${aws_eip.web_server_eip.public_ip}
    
    SSH Command (if you have the key):
    ssh -i /home/jilg/Downloads/temp_files/jp_rsa_key ec2-user@${aws_eip.web_server_eip.public_ip}
    
    View generated password (on server):
    sudo cat /tmp/demo_password.txt
  EOT
}


# Output 5: SSH connection information
output "ssh_private_key_path" {
  description = "Path to SSH private key file"
  value       = local_file.private_key.filename
}

output "ssh_connection_command" {
  description = "Command to SSH into the instance"
  value       = "ssh -i ${local_file.private_key.filename} ec2-user@${aws_eip.web_server_eip.public_ip}"
}

output "key_pair_name" {
  description = "Name of the created key pair"
  value       = aws_key_pair.web_server_key.key_name
}
