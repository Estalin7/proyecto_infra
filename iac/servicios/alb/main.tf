# alb
# Crea: ALB INTERNO conectado via VPC Link desde API Gateway

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_lb" "main" {
  name               = "${var.project}-alb-${var.environment}"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [var.sg_alb_id]
  subnets            = var.private_subnet_ids

  enable_deletion_protection = var.environment == "prod" ? true : false

  # Habilitar access logs hacia S3
  access_logs {
    bucket  = var.s3_logs_bucket_id
    enabled = true
    prefix  = "alb-logs"
  }

  tags = {
    Name        = "${var.project}-alb-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Target Group (EC2 instancias CRUD) ───────────────────────
resource "aws_lb_target_group" "crud" {
  name        = "${var.project}-tg-crud-${var.environment}"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name        = "${var.project}-tg-crud-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Listener HTTP (80) → Target Group ──────────────────────
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.crud.arn
  }
}
