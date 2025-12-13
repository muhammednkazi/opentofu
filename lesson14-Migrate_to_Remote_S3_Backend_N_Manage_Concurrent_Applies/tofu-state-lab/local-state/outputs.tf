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
