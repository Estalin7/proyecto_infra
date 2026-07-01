resource "aws_lb" "main" {
  #checkov:skip=CKV2_AWS_28:ALB es interno; no está expuesto a internet, el WAF protege CloudFront como única entrada pública
  name               = "${var.project}-alb-${var.environment}"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.private[*].id

  enable_deletion_protection = false
  drop_invalid_header_fields = true

  access_logs {
    bucket  = aws_s3_bucket.logs.id
    prefix  = "${var.project}/${var.environment}/alb"
    enabled = true
  }

  tags = {
    Name        = "${var.project}-alb-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }

  depends_on = [aws_s3_bucket_policy.logs]
}

resource "aws_lb_target_group" "crud" {
  name        = substr("${var.project}-tg-crud-${var.environment}", 0, 32)
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
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

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.crud.arn
  }
}

# Nota: se elimino el listener HTTPS (443) ya que dependia de un
# certificado ACM con dominio propio (restaurant.com / Cloudflare),
# que se descarto. El ALB es interno (no expuesto a internet) y
# solo se accede via API Gateway, por lo que HTTP es suficiente
# para este entorno academico.
