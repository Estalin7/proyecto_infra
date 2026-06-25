resource "aws_lambda_function" "procesar_pedido" {
  #checkov:skip=CKV_AWS_272:Code signing no compatible con ZIPs locales para despliegue academico
  #checkov:skip=CKV_AWS_173:KMS para variables de entorno no requerido para despliegue academico
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

  filename         = "${path.module}/../../../lambdas/procesar_pedido/procesar_pedido.zip"
  source_code_hash = filebase64sha256("${path.module}/../../../lambdas/procesar_pedido/procesar_pedido.zip")


  # Habilitar X-Ray tracing → Fix CKV_AWS_50
  tracing_config {
    mode = "Active"
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.sg_lambda_id]
  }

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
  #checkov:skip=CKV_AWS_272:Code signing no compatible con ZIPs locales para despliegue academico
  #checkov:skip=CKV_AWS_173:KMS para variables de entorno no requerido para despliegue academico
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

  filename         = "${path.module}/../../../lambdas/enviar_sms_cocina/enviar_sms_cocina.zip"
  source_code_hash = filebase64sha256("${path.module}/../../../lambdas/enviar_sms_cocina/enviar_sms_cocina.zip")

  # Habilitar X-Ray tracing → Fix CKV_AWS_50
  tracing_config {
    mode = "Active"
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.sg_lambda_id]
  }


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
  #checkov:skip=CKV_AWS_272:Code signing no compatible con ZIPs locales para despliegue academico
  #checkov:skip=CKV_AWS_173:KMS para variables de entorno no requerido para despliegue academico
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

  filename         = "${path.module}/../../../lambdas/actualizar_inventario/actualizar_inventario.zip"
  source_code_hash = filebase64sha256("${path.module}/../../../lambdas/actualizar_inventario/actualizar_inventario.zip")

  # Habilitar X-Ray tracing → Fix CKV_AWS_50
  tracing_config {
    mode = "Active"
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.sg_lambda_id]
  }


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

