resource "aws_wafv2_web_acl" "main" {
  provider    = aws.us_east_1
  name        = "${var.project}-waf-${var.environment}"
  description = "WAF para CloudFront del proyecto ${var.project}"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # Regla 1: Proteccion contra ataques comunes (SQLi, XSS, etc.)
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # Regla 2: Proteccion contra IPs maliciosas conocidas
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  # Regla 3: Rate limiting (evita abuso / DDoS basico)
  rule {
    name     = "RateLimitRule"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  # Regla 4: Proteccion contra Log4j (CVE-2021-44228) → Fix CKV_AWS_192 y CKV2_AWS_47
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project}-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "${var.project}-waf-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── KMS key para WAF logs (Fix CKV_AWS_158) ──────────────────
resource "aws_kms_key" "waf_logs" {
  provider                = aws.us_east_1
  description             = "KMS key para WAF logs ${var.project}-${var.environment}"
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
    Name        = "${var.project}-kms-waf-logs-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── CloudWatch Log Group para WAF (Fix CKV2_AWS_31) ──────────
# IMPORTANTE: el nombre DEBE empezar con "aws-waf-logs-"
resource "aws_cloudwatch_log_group" "waf_logs" {
  provider          = aws.us_east_1
  name              = "aws-waf-logs-${var.project}-${var.environment}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.waf_logs.arn

  tags = {
    Name        = "${var.project}-waf-logs-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Logging Configuration del WAF (Fix CKV2_AWS_31) ──────────
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  provider                = aws.us_east_1
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs.arn]
  resource_arn            = aws_wafv2_web_acl.main.arn
}

data "aws_caller_identity" "current" {}
