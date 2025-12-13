# Generate a new SSH key pair using TLS provider
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS key pair from generated public key
resource "aws_key_pair" "web_server_key" {
  key_name   = "web-server-${random_id.server_suffix.hex}"
  public_key = tls_private_key.ssh_key.public_key_openssh

  tags = {
    Name = "web-server-key-${random_id.server_suffix.hex}"
  }
}

# Save private key to local file
resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/ssh-key-${random_id.server_suffix.hex}.pem"
  file_permission = "0600"
}
