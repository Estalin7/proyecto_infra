resource "aws_lambda_function" "procesar_pedido" {
  function_name                  = "${var.project}-procesar-pedido-${var.environment}"
  role                           = var.lambda_role_arn
  handler                        = "index.handler"
  runtime                        = "nodejs20.x"
  timeout                        = 60
  memory_size                    = 256
  reserved_concurrent_executions = 10

  dead_letter_config {
    target_arn = var.dlq_arn
  }

  s3_bucket = var.artifacts_bucket
  s3_key    = "lambdas/procesar_pedido.zip"

  code_signing_config_arn = aws_lambda_code_signing_config.lambda_signing.arn

  # Habilitar X-Ray tracing → Fix CKV_AWS_50
  tracing_config {
    mode = "Active"
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.sg_lambda_id]
  }
  kms_key_arn = var.kms_key_arn

  environment {
    variables = {
      ENVIRONMENT           = var.environment
      LAMBDA_ENVIAR_SMS_ARN = aws_lambda_function.enviar_sms_cocina.arn
      SQS_PEDIDOS_URL       = var.sqs_pedidos_url
      AURORA_HOST           = var.aurora_host
      AURORA_PORT           = "5432"
      AURORA_DB_NAME        = var.aurora_db_name
      AURORA_USER           = var.aurora_username
      AURORA_PASSWORD       = var.aurora_password
      REDIS_HOST            = var.redis_host
    }
  }

  tags = {
    Name        = "${var.project}-procesar-pedido-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Lambda 2: enviar_sms_cocina ──────────────────────────────
resource "aws_lambda_function" "enviar_sms_cocina" {
  function_name                  = "${var.project}-enviar-sms-cocina-${var.environment}"
  role                           = var.lambda_role_arn
  handler                        = "index.handler"
  runtime                        = "nodejs20.x"
  timeout                        = 30
  memory_size                    = 128
  reserved_concurrent_executions = 10

  dead_letter_config {
    target_arn = var.dlq_arn
  }

  s3_bucket = var.artifacts_bucket
  s3_key    = "lambdas/enviar_sms_cocina.zip"

  code_signing_config_arn = aws_lambda_code_signing_config.lambda_signing.arn
  # Habilitar X-Ray tracing → Fix CKV_AWS_50
  tracing_config {
    mode = "Active"
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.sg_lambda_id]
  }

  kms_key_arn = var.kms_key_arn

  environment {
    variables = {
      ENVIRONMENT     = var.environment
      TELEFONO_COCINA = var.telefono_cocina
    }
  }

  tags = {
    Name        = "${var.project}-enviar-sms-cocina-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Lambda 3: actualizar_inventario ──────────────────────────
resource "aws_lambda_function" "actualizar_inventario" {
  function_name                  = "${var.project}-actualizar-inventario-${var.environment}"
  role                           = var.lambda_role_arn
  handler                        = "index.handler"
  runtime                        = "nodejs20.x"
  timeout                        = 60
  memory_size                    = 256
  reserved_concurrent_executions = 10

  dead_letter_config {
    target_arn = var.dlq_arn
  }

  s3_bucket = var.artifacts_bucket
  s3_key    = "lambdas/actualizar_inventario.zip"

  code_signing_config_arn = aws_lambda_code_signing_config.lambda_signing.arn
  # Habilitar X-Ray tracing → Fix CKV_AWS_50
  tracing_config {
    mode = "Active"
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.sg_lambda_id]
  }

  kms_key_arn = var.kms_key_arn

  environment {
    variables = {
      ENVIRONMENT     = var.environment
      S3_DOCUMENTOS   = var.s3_documentos_bucket
      AURORA_HOST     = var.aurora_host
      AURORA_PORT     = "5432"
      AURORA_DB_NAME  = var.aurora_db_name
      AURORA_USER     = var.aurora_username
      AURORA_PASSWORD = var.aurora_password
    }
  }

  tags = {
    Name        = "${var.project}-actualizar-inventario-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── KMS key para CloudWatch Log Groups (Fix CKV_AWS_158) ─────
resource "aws_kms_key" "lambda_logs" {
  description             = "KMS key para logs de Lambda ${var.project}-${var.environment}"
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
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
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
    Name        = "${var.project}-kms-lambda-logs-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── CloudWatch Log Groups (retencion 365 dias) → Fix CKV_AWS_338 ─
resource "aws_cloudwatch_log_group" "procesar_pedido" {
  name              = "/aws/lambda/${aws_lambda_function.procesar_pedido.function_name}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.lambda_logs.arn
}

resource "aws_cloudwatch_log_group" "enviar_sms_cocina" {
  name              = "/aws/lambda/${aws_lambda_function.enviar_sms_cocina.function_name}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.lambda_logs.arn
}

resource "aws_cloudwatch_log_group" "actualizar_inventario" {
  name              = "/aws/lambda/${aws_lambda_function.actualizar_inventario.function_name}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.lambda_logs.arn
}

resource "aws_signer_signing_profile" "lambda_profile" {
  name_prefix = "profile_${var.environment}"
  platform_id = "AWSLambda-SHA384-ECDSA"
}

resource "aws_lambda_code_signing_config" "lambda_signing" {
  allowed_publishers {
    signing_profile_version_arns = [aws_signer_signing_profile.lambda_profile.version_arn]
  }

  policies {
    untrusted_artifact_on_deployment = "Warn"
  }
}