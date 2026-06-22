terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name        = "${var.project}-hz-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Registro apex (restaurant.com) → CloudFront ─────────────
resource "aws_route53_record" "apex" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

# ── Registro www (www.restaurant.com) → CloudFront ──────────
resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

# ── Registros CNAME para validacion ACM (DNS validation) ─────
# Se crean dinamicamente desde los registros que devuelve ACM
resource "aws_route53_record" "acm_validation" {
  for_each = var.acm_validation_records

  zone_id = aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}
