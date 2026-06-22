# ============================================================
# MODULE: s3
# Crea: dos buckets S3
#   - frontend: archivos estaticos servidos por CloudFront
#   - documentos: almacena documentos generados por Lambda
# ============================================================
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}
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
    status = "Enabled"
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

# Cifrado SSE-S3 para el bucket frontend
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Politica: solo CloudFront (OAC) puede hacer GetObject
resource "aws_s3_bucket_policy" "frontend" {
  count  = var.cloudfront_distribution_arn != "" ? 1 : 0
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
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "documentos" {
  bucket                  = aws_s3_bucket.documentos.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Cifrado SSE-S3 para el bucket de documentos
resource "aws_s3_bucket_server_side_encryption_configuration" "documentos" {
  bucket = aws_s3_bucket.documentos.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle: mover documentos a Glacier despues de 90 dias
resource "aws_s3_bucket_lifecycle_configuration" "documentos" {
  bucket = aws_s3_bucket.documentos.id

  rule {
    id     = "archive-old-documents"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }
}

# ── Bucket para logs (ALB, CloudFront, etc.) ─────────────────
resource "aws_s3_bucket" "logs" {
  bucket = "${var.project}-logs-${var.environment}"

  tags = {
    Name        = "${var.project}-logs-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Cifrado SSE-S3 para el bucket de logs
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle: borrar logs despues de 90 dias (reducir costos)
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "delete-old-logs"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 90
    }
  }
}
