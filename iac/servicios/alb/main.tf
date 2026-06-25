# ALB  apuntando a las EC2 CRUD.
resource "aws_lb" "main" {
  #checkov:skip=CKV_AWS_91:Access logs del ALB deshabilitados para despliegue academico
  name               = "${var.project}-alb-${var.environment}"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [var.sg_alb_id]
  subnets            = var.private_subnet_ids

  enable_deletion_protection = var.environment == "prod" ? true : false
  drop_invalid_header_fields = true

  access_logs {
    bucket  = ""
    prefix  = "${var.project}/${var.environment}/alb"
    enabled = false
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

# ── Listener HTTP (80) → redirige a HTTPS ────────────────────
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ── Listener HTTPS (443) → Target Group ──────────────────────
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.crud.arn
  }
}
