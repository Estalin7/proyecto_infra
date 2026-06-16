# ============================================================
# MODULE: s3
# Crea: dos buckets S3
#   - frontend: archivos estaticos servidos por CloudFront
#   - documentos: almacena documentos generados por Lambda
# ============================================================

# ── Bucket frontend (estatico) ───────────────────────────────
resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project}-frontend-${var.environment}"

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

# Bloquear acceso publico: solo CloudFront via OAC puede leer
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Politica: solo CloudFront (OAC) puede hacer GetObject
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAC"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = var.cloudfront_distribution_arn
          }
        }
      }
    ]
  })
}

# ── Bucket documentos (generados por Lambda) ─────────────────
resource "aws_s3_bucket" "documentos" {
  bucket = "${var.project}-documentos-${var.environment}"

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

# Lifecycle: mover documentos a Glacier despues de 90 dias
resource "aws_s3_bucket_lifecycle_configuration" "documentos" {
  bucket = aws_s3_bucket.documentos.id

  rule {
    id     = "archive-old-documents"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Cancelar uploads incompletos despues de 7 dias → Fix CKV_AWS_300
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ── Bucket de logs (destino de access logging) ───────────────
resource "aws_s3_bucket" "logs" {
  bucket = "${var.project}-logs-${var.environment}"

  tags = {
    Name        = "${var.project}-logs-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Disabled"
  }
}

# Lifecycle: expirar logs despues de 90 dias para optimizar costos
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    id     = "expire-old-logs"
    status = "Enabled"
    expiration {
      days = 90
    }
    # Cancelar uploads incompletos despues de 7 dias → Fix CKV_AWS_300
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Habilitar access logging para el bucket frontend → Fix CKV_AWS_18
resource "aws_s3_bucket_logging" "frontend" {
  bucket        = aws_s3_bucket.frontend.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "logs/frontend/"
}

# Habilitar access logging para el bucket documentos → Fix CKV_AWS_18
resource "aws_s3_bucket_logging" "documentos" {
  bucket        = aws_s3_bucket.documentos.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "logs/documentos/"
}
