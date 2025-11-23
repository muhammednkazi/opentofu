# Expose module outputs at root level
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "app_server_ip" {
  description = "Application server public IP"
  value       = aws_instance.app_server.public_ip
}