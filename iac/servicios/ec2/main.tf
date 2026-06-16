# ============================================================
# MODULE: compute
# Crea: 2 instancias EC2 Ubuntu 22.04 t3.medium (una por AZ)
#       en subnets privadas + registro en el Target Group ALB.
#       Ansible se encarga de instalar el JAR despues.
# ============================================================

# Busca el AMI de Ubuntu 22.04 LTS mas reciente en us-east-2
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (propietario oficial Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── Instancias EC2 (una por AZ) ─────────────────────────────
resource "aws_instance" "crud" {
  count         = length(var.private_subnet_ids)
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  subnet_id                   = var.private_subnet_ids[count.index]
  vpc_security_group_ids      = [var.sg_ec2_id]
  iam_instance_profile        = var.iam_instance_profile_name
  associate_public_ip_address = false

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

  # User data minimo: instala el agente SSM para acceso sin SSH abierto
  user_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update -y
    snap install amazon-ssm-agent --classic
    systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
    systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
  EOF
  )

  tags = {
    Name        = "${var.project}-ec2-crud-az${count.index + 1}-${var.environment}"
    Project     = var.project
    Environment = var.environment
    # Tag usado por Ansible para identificar el grupo de hosts
    Role = "crud"
  }
}

# ── Registro de las EC2 en el Target Group del ALB ──────────
resource "aws_lb_target_group_attachment" "crud" {
  count            = length(aws_instance.crud)
  target_group_arn = var.target_group_arn
  target_id        = aws_instance.crud[count.index].id
  port             = var.app_port
}