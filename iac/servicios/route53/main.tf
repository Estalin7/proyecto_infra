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

resource "aws_route53_key_signing_key" "main" {
  hosted_zone_id             = aws_route53_zone.main.zone_id
  key_management_service_arn = var.dnssec_kms_key_arn
  name                       = "${var.project}-dnssec-${var.environment}"
}

resource "aws_route53_hosted_zone_dnssec" "main" {
  hosted_zone_id = aws_route53_zone.main.zone_id

  depends_on = [aws_route53_key_signing_key.main]
}
