# Web Servers
resource "aws_instance" "web" {
  count                  = 2
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public[count.index].id
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Web Server ${count.index + 1}</h1>" > /var/www/html/index.html
              echo "<p>Hostname: $(hostname)</p>" >> /var/www/html/index.html
              echo "<p>Instance ID: $(ec2-metadata --instance-id | cut -d ' ' -f 2)</p>" >> /var/www/html/index.html
              EOF

  tags = {
    Name = "${var.project_name}-web-${count.index + 1}"
  }
}
