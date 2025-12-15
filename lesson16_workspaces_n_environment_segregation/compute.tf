# Generate SSH key
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = "${terraform.workspace}-deployer-key"
  public_key = tls_private_key.ssh.public_key_openssh

  tags = {
    Name = "${terraform.workspace}-deployer-key"
  }
}

# Web Server Instances
resource "aws_instance" "web" {
  count                  = local.env.instance_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = local.env.instance_type
  subnet_id              = aws_subnet.public[count.index % length(aws_subnet.public)].id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.deployer.key_name

  monitoring = local.env.enable_monitoring

  root_block_device {
    volume_size = local.env.volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    workspace      = terraform.workspace
    instance_index = count.index + 1
    instance_count = local.env.instance_count
  })

  tags = {
    Name  = "${terraform.workspace}-web-${count.index + 1}"
    Role  = "webserver"
    Index = count.index + 1
  }

  lifecycle {
    create_before_destroy = true
  }
}

# CloudWatch alarms (production only)
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count               = terraform.workspace == "prod" ? local.env.instance_count : 0
  alarm_name          = "${terraform.workspace}-web-${count.index + 1}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors ec2 cpu utilization"

  dimensions = {
    InstanceId = aws_instance.web[count.index].id
  }

  tags = {
    Name = "${terraform.workspace}-web-${count.index + 1}-cpu-alarm"
  }
}
