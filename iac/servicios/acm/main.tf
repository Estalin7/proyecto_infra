terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.us_east_1]
    }
  }
}
resource "aws_acm_certificate" "cloudfront" {
  provider          = aws.us_east_1
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "www.${var.domain_name}"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.project}-cert-cloudfront-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Certificado para ALB (us-east-2, misma region del ALB) ──
resource "aws_acm_certificate" "alb" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "www.${var.domain_name}"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.project}-cert-alb-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# Esperar validacion del certificado CloudFront
resource "aws_acm_certificate_validation" "cloudfront" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cloudfront.arn
  validation_record_fqdns = [for record in aws_acm_certificate.cloudfront.domain_validation_options : record.resource_record_name]
}

# Esperar validacion del certificado ALB
resource "aws_acm_certificate_validation" "alb" {
  certificate_arn         = aws_acm_certificate.alb.arn
  validation_record_fqdns = [for record in aws_acm_certificate.alb.domain_validation_options : record.resource_record_name]
}
