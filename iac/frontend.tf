# ============================================================
# frontend.tf
# Crea: S3 (frontend, docs, logs), CloudFront CDN (dominio
#       default *.cloudfront.net, sin dominio propio), OAC.
# ============================================================

# Nota: se descartaron ACM, Route 53 y dominio personalizado.
# CloudFront usa su certificado y dominio default
# (*.cloudfront.net), que ya viene con HTTPS incluido.
# El ALB es interno y no necesita certificado propio.


# ═══════════════════════════════════════════════════════════════
# S3 BUCKETS
# ═══════════════════════════════════════════════════════════════

data "aws_iam_policy_document" "s3_kms" {
  statement {
    sid    = "EnableAccountAdministration"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions = [
      "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*", "kms:Put*",
      "kms:Update*", "kms:Revoke*", "kms:Disable*", "kms:Get*", "kms:Delete*",
      "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion"
    ]

    resources = ["arn:${data.aws_partition.current.partition}:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid    = "AllowCloudFrontDecrypt"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = ["arn:${data.aws_partition.current.partition}:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*"]
  }
}

resource "aws_kms_key" "s3_app" {
  description             = "Clave KMS para los buckets frontend y documentos"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.s3_kms.json

  tags = {
    Name        = "${var.project}-s3-kms-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_kms_alias" "s3_app" {
  name          = "alias/${var.project}-s3-${var.environment}"
  target_key_id = aws_kms_key.s3_app.key_id
}

# ── Bucket Frontend ──────────────────────────────────────────
resource "aws_s3_bucket" "frontend" {
  #checkov:skip=CKV_AWS_144:Replicacion cross-region no requerida
  bucket        = "${var.project}-frontend-${var.environment}"
  force_destroy = true

  tags = {
    Name        = "${var.project}-frontend-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Disabled"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule {
    bucket_key_enabled = true
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_app.arn
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "frontend" {
  bucket     = aws_s3_bucket.frontend.id
  depends_on = [aws_s3_bucket_versioning.frontend]

  rule {
    id     = "cleanup-old-frontend-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration { noncurrent_days = 30 }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}

# ── Bucket Documentos ────────────────────────────────────────
resource "aws_s3_bucket" "documentos" {
  #checkov:skip=CKV_AWS_144:Replicacion cross-region no requerida
  bucket        = "${var.project}-documentos-${var.environment}"
  force_destroy = true

  tags = {
    Name        = "${var.project}-documentos-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "documentos" {
  bucket = aws_s3_bucket.documentos.id
  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Disabled"
  }
}

resource "aws_s3_bucket_public_access_block" "documentos" {
  bucket                  = aws_s3_bucket.documentos.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "documentos" {
  bucket = aws_s3_bucket.documentos.id
  rule {
    bucket_key_enabled = true
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_app.arn
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "documentos" {
  bucket = aws_s3_bucket.documentos.id
  rule {
    id     = "archive-old-documents"
    status = "Enabled"
    filter {}
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}

# ── Bucket Logs ──────────────────────────────────────────────
resource "aws_s3_bucket" "logs" {
  #checkov:skip=CKV_AWS_144:Replicacion cross-region no requerida
  bucket        = "${var.project}-logs-${var.environment}"
  force_destroy = true

  tags = {
    Name        = "${var.project}-logs-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Disabled"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    # ALB access logs no soportan buckets cifrados con SSE-KMS,
    # solo AES256 (SSE-S3). El bucket es destino de logs, no de
    # datos de negocio, por lo que AES256 es suficiente.
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_canonical_user_id" "current" {}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "logs" {
  depends_on = [aws_s3_bucket_ownership_controls.logs]
  bucket     = aws_s3_bucket.logs.id
  access_control_policy {
    owner {
      id = data.aws_canonical_user_id.current.id
    }
    grant {
      grantee {
        id   = data.aws_canonical_user_id.current.id
        type = "CanonicalUser"
      }
      permission = "FULL_CONTROL"
    }

    grant {
      grantee {
        type = "CanonicalUser"
        # The canonical user ID for awslogsdelivery account is predefined
        id   = "c4c1ede66af53448b93c283ce9448c4ba468c9432aa01d700d3878632f77d2d0"
      }
      permission = "FULL_CONTROL"
    }
  }
}

data "aws_elb_service_account" "main" {}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowS3ServerAccessLogs"
        Effect    = "Allow"
        Principal = { Service = "logging.s3.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.logs.arn}/logs/*"
        Condition = {
          ArnLike      = { "aws:SourceArn" = [aws_s3_bucket.frontend.arn, aws_s3_bucket.documentos.arn] }
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        }
      },
      {
        Sid       = "AllowALBAccessLogs"
        Effect    = "Allow"
        Principal = { AWS = data.aws_elb_service_account.main.arn }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.logs.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    id     = "expire-old-logs"
    status = "Enabled"
    filter {}
    expiration { days = 90 }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}

resource "aws_s3_bucket_logging" "frontend" {
  bucket        = aws_s3_bucket.frontend.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "logs/frontend/"
  depends_on    = [aws_s3_bucket_policy.logs, aws_s3_bucket_server_side_encryption_configuration.logs]
}

resource "aws_s3_bucket_logging" "documentos" {
  bucket        = aws_s3_bucket.documentos.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "logs/documentos/"
  depends_on    = [aws_s3_bucket_policy.logs, aws_s3_bucket_server_side_encryption_configuration.logs]
}

resource "aws_s3_bucket_notification" "frontend" {
  bucket      = aws_s3_bucket.frontend.id
  eventbridge = true
}

resource "aws_s3_bucket_notification" "documentos" {
  bucket      = aws_s3_bucket.documentos.id
  eventbridge = true
}

resource "aws_s3_bucket_notification" "logs" {
  bucket      = aws_s3_bucket.logs.id
  eventbridge = true
}


# ═══════════════════════════════════════════════════════════════
# CLOUDFRONT
# ═══════════════════════════════════════════════════════════════

resource "aws_cloudfront_origin_access_control" "main" {
  name                              = "${var.project}-oac-${var.environment}"
  description                       = "OAC para bucket S3 frontend ${var.project}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

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
    content_type_options { override = true }
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

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = var.cf_price_class
  comment             = "${var.project} CDN frontend ${var.environment}"

  logging_config {
    bucket          = aws_s3_bucket.logs.bucket_domain_name
    prefix          = "${var.project}/${var.environment}/cloudfront"
    include_cookies = false
  }

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3-${var.project}-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }

  origin {
    domain_name              = aws_s3_bucket.documentos.bucket_regional_domain_name
    origin_id                = "S3-${var.project}-failover"
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }

  origin_group {
    origin_id = "S3-${var.project}-group"
    failover_criteria { status_codes = [500, 502, 503, 504] }
    member { origin_id = "S3-${var.project}-frontend" }
    member { origin_id = "S3-${var.project}-failover" }
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
      cookies { forward = "none" }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

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
    cloudfront_default_certificate = true
  }

  web_acl_id = aws_wafv2_web_acl.main.arn

  tags = {
    Name        = "${var.project}-cf-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Bucket Policy OAC (rompe ciclo CloudFront ↔ S3) ─────────
resource "aws_s3_bucket_policy" "frontend_oac" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontOAC"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.frontend.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
        }
      }
    }]
  })

  depends_on = [aws_s3_bucket.frontend, aws_cloudfront_distribution.main]
}

# Nota: se eliminó toda la sección de Route 53 (hosted zone,
# query logs, registros apex/www, validacion ACM) ya que el
# proyecto no usa un dominio personalizado. CloudFront se sirve
# desde su dominio default *.cloudfront.net.
