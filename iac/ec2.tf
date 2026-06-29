data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── Instancias EC2 (una por AZ) ──────────────────────────────
resource "aws_instance" "crud" {
  count         = length(aws_subnet.private)
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.ec2_instance_type

  subnet_id                   = aws_subnet.private[count.index].id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = false
  monitoring                  = true
  ebs_optimized               = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
  EOF
  )

  tags = {
    Name        = "${var.project}-ec2-crud-az${count.index + 1}-${var.environment}"
    Project     = var.project
    Environment = var.environment
    Role        = "crud"
  }
}

# ── Registro en Target Group del ALB ─────────────────────────
resource "aws_lb_target_group_attachment" "crud" {
  count            = length(aws_instance.crud)
  target_group_arn = aws_lb_target_group.crud.arn
  target_id        = aws_instance.crud[count.index].id
  port             = var.app_port
}
