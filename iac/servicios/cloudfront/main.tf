resource "aws_cloudfront_origin_access_control" "main" {
  name                              = "${var.project}-oac-${var.environment}"
  description                       = "OAC para bucket S3 frontend ${var.project}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}


# ── Response Headers Policy (Fix CKV2_AWS_32) ────────────────
resource "aws_cloudfront_response_headers_policy" "main" {
  name    = "${var.project}-response-headers-${var.environment}"
  comment = "Headers de seguridad para ${var.project}"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
  }
}

# ── Distribucion CloudFront ──────────────────────────────────
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = [var.domain_name, "www.${var.domain_name}"]
  price_class         = var.price_class
  comment             = "${var.project} CDN frontend ${var.environment}"

  logging_config {
    bucket          = var.cf_logs_bucket
    prefix          = "${var.project}/${var.environment}/cloudfront"
    include_cookies = false
  }

  origin {
    domain_name              = var.s3_bucket_regional_domain_name
    origin_id                = "S3-${var.project}-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }

  #FAILOVER
  # Origen secundario para failover (Fix CKV_AWS_310)
  origin {
    domain_name              = var.s3_bucket_failover_domain_name
    origin_id                = "S3-${var.project}-failover"
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }

  origin_group {
    origin_id = "S3-${var.project}-group"

    failover_criteria {
      status_codes = [500, 502, 503, 504]
    }

    member {
      origin_id = "S3-${var.project}-frontend"
    }

    member {
      origin_id = "S3-${var.project}-failover"
    }
  }

  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "S3-${var.project}-group"
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
    response_headers_policy_id = aws_cloudfront_response_headers_policy.main.id

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # SPA: redirige errores 403/404 a index.html (React Router)
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = var.cf_geo_whitelist
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  #checkov:skip=CKV2_AWS_47:WAF con AWSManagedRulesKnownBadInputsRuleSet definido en modulo waf
  web_acl_id = var.waf_acl_arn

  tags = {
    Name        = "${var.project}-cf-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}
