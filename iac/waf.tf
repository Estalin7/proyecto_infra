# ============================================================
# waf.tf
# Crea: WAF Web ACL (scope CLOUDFRONT, us-east-1) con:
#   - Reglas gestionadas AWS (Common, IP Reputation, Log4j)
#   - Rate limiting por IP
#   - CloudWatch Logs con KMS
# ============================================================

resource "aws_wafv2_web_acl" "main" {
  count       = var.enable_waf ? 1 : 0
  provider    = aws.us_east_1
  name        = "${var.project}-waf-${var.environment}"
  description = "WAF para CloudFront del proyecto ${var.project}"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

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

  rule {
    name     = "RateLimitRule"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

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

  # Corrige CKV2_AWS_47 junto con KnownBadInputsRuleSet.
  rule {
    name     = "AWSManagedRulesAnonymousIpList"
    priority = 5

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAnonymousIpList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-anonymous-ip-list"
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

# El nombre debe comenzar con "aws-waf-logs-".
resource "aws_cloudwatch_log_group" "waf_logs" {
  count             = var.enable_waf ? 1 : 0
  provider          = aws.us_east_1
  name              = "aws-waf-logs-${var.project}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project}-waf-logs-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  count                   = var.enable_waf ? 1 : 0
  provider                = aws.us_east_1
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs[0].arn]
  resource_arn            = aws_wafv2_web_acl.main[0].arn
}
