# Output file - separating outputs improves organization

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.web_server.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.web_server.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.web_server.public_dns
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.web_sg.id
}

output "website_url" {
  description = "URL to access the web server"
  value       = "http://${aws_instance.web_server.public_ip}"
}