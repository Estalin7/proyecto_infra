resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name        = "${var.project}-hz-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_kms_key" "route53_logs" {
  provider                = aws.us_east_1
  description             = "KMS key para Route 53 query logs ${var.project}-${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.us-east-1.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project}-kms-route53-logs-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── CloudWatch Log Group para DNS query logging ───────────────
# IMPORTANTE: Route 53 query logs SIEMPRE van a us-east-1
resource "aws_cloudwatch_log_group" "route53_queries" {
  provider          = aws.us_east_1
  name              = "/aws/route53/${var.domain_name}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.route53_logs.arn

  tags = {
    Name        = "${var.project}-route53-query-logs-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Politica que permite a Route 53 escribir en el log group ──
resource "aws_cloudwatch_log_resource_policy" "route53_queries" {
  provider    = aws.us_east_1
  policy_name = "${var.project}-route53-query-log-policy-${var.environment}"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowRoute53Logging"
        Effect = "Allow"
        Principal = {
          Service = "route53.amazonaws.com"
        }
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/route53/*"
      }
    ]
  })
}

# ── Habilitar query logging en la hosted zone ─────────────────
resource "aws_route53_query_log" "main" {
  zone_id                  = aws_route53_zone.main.zone_id
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.route53_queries.arn

  depends_on = [aws_cloudwatch_log_resource_policy.route53_queries]
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

data "aws_caller_identity" "current" {}
