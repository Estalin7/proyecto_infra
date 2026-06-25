terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

# CLAVE KMS PARA FRONTEND Y DOCUMENTOS

data "aws_iam_policy_document" "s3_kms" {

  statement {
    sid    = "EnableAccountAdministration"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }

    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion"
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*"
    ]

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

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*"
    ]
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

# BUCKET FRONTEND


resource "aws_s3_bucket" "frontend" {
  #checkov:skip=CKV_AWS_144:Replicacion cross-region no requerida para este proyecto academico
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

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Cifrado SSE-KMS → CKV_AWS_145
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

# CloudFront OAC es el único que puede leer el frontend.


# Lifecycle del frontend → CKV2_AWS_61
resource "aws_s3_bucket_lifecycle_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  depends_on = [
    aws_s3_bucket_versioning.frontend
  ]

  rule {
    id     = "cleanup-old-frontend-versions"
    status = "Enabled"

    filter {}

    # Elimina versiones anteriores después de 30 días.
    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    # Elimina cargas multipart incompletas después de 7 días.
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# BUCKET DOCUMENTOS

resource "aws_s3_bucket" "documentos" {
  #checkov:skip=CKV_AWS_144:Replicacion cross-region no requerida para este proyecto academico

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
  bucket = aws_s3_bucket.documentos.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Cifrado SSE-KMS → CKV_AWS_145
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

    # Archiva los documentos antiguos en Glacier.
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# BUCKET DE LOGS

resource "aws_s3_bucket" "logs" {
  #checkov:skip=CKV_AWS_144:Replicacion cross-region no requerida para este proyecto academico


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
    status     = "Enabled"
    mfa_delete = "Disabled"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# El bucket es destino de S3 Server Access Logging.
# AWS exige SSE-S3 para este tipo de destino.
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_app.arn
    }
  }
}

# Permite al servicio de logging de S3 escribir los registros.
resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "AllowS3ServerAccessLogs"
        Effect = "Allow"

        Principal = {
          Service = "logging.s3.amazonaws.com"
        }

        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs.arn}/logs/*"

        Condition = {
          ArnLike = {
            "aws:SourceArn" = [
              aws_s3_bucket.frontend.arn,
              aws_s3_bucket.documentos.arn
            ]
          }

          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
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

    expiration {
      days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# S3 SERVER ACCESS LOGGING

resource "aws_s3_bucket_logging" "frontend" {
  bucket        = aws_s3_bucket.frontend.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "logs/frontend/"

  depends_on = [
    aws_s3_bucket_policy.logs,
    aws_s3_bucket_server_side_encryption_configuration.logs
  ]
}

resource "aws_s3_bucket_logging" "documentos" {
  bucket        = aws_s3_bucket.documentos.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "logs/documentos/"

  depends_on = [
    aws_s3_bucket_policy.logs,
    aws_s3_bucket_server_side_encryption_configuration.logs
  ]
}

# NOTIFICACIONES DE EVENTOS

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

data "aws_region" "current" {}