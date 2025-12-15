output "workspace" {
  description = "Current workspace"
  value       = terraform.workspace
}

output "environment_config" {
  description = "Configuration for current environment"
  value = {
    instance_type  = local.env.instance_type
    instance_count = local.env.instance_count
    vpc_cidr       = local.env.vpc_cidr
  }
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "web_server_ips" {
  description = "Public IPs of web servers"
  value = {
    for idx, instance in aws_instance.web :
    "web-${idx + 1}" => instance.public_ip
  }
}

output "web_urls" {
  description = "URLs to access web servers"
  value = [
    for instance in aws_instance.web :
    "http://${instance.public_ip}"
  ]
}

output "ssh_private_key" {
  description = "SSH private key for connecting to instances"
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}

output "ssh_commands" {
  description = "SSH commands to connect to each instance"
  value = {
    for idx, instance in aws_instance.web :
    "web-${idx + 1}" => "ssh -i ${terraform.workspace}-key.pem ubuntu@${instance.public_ip}"
  }
}
