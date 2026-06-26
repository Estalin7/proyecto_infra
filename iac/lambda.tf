# ============================================================
# lambda.tf
# Crea: 3 funciones Lambda + CloudWatch Log Groups
#   1. procesar_pedido      - consume SQS, envía SMS
#   2. enviar_sms_cocina    - envía SMS vía SNS
#   3. actualizar_inventario - actualiza S3 + Aurora
# ============================================================

# ── KMS key para CloudWatch Log Groups de Lambda ─────────────
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
        Action   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey"]
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

# ── Lambda 1: procesar_pedido ─────────────────────────────────
resource "aws_lambda_function" "procesar_pedido" {
  #checkov:skip=CKV_AWS_272:Code signing no compatible con ZIPs locales
  #checkov:skip=CKV_AWS_173:KMS para variables de entorno no requerido para despliegue academico
  function_name                  = "${var.project}-procesar-pedido-${var.environment}"
  role                           = aws_iam_role.lambda.arn
  handler                        = "index.handler"
  runtime                        = "nodejs20.x"
  timeout                        = 60
  memory_size                    = 256
  reserved_concurrent_executions = 10

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

  filename         = "${path.module}/../lambdas/procesar_pedido/procesar_pedido.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambdas/procesar_pedido/procesar_pedido.zip")

  tracing_config {
    mode = "Active"
  }

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      ENVIRONMENT           = var.environment
      LAMBDA_ENVIAR_SMS_ARN = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${var.project}-enviar-sms-cocina-${var.environment}"
      SQS_PEDIDOS_URL       = aws_sqs_queue.pedidos.url
      AURORA_HOST           = aws_rds_cluster.main.endpoint
      AURORA_PORT           = "5432"
      AURORA_DB_NAME        = var.db_name
      AURORA_USER           = var.db_username
      AURORA_PASSWORD       = var.db_password
      REDIS_HOST            = aws_elasticache_replication_group.main.primary_endpoint_address
    }
  }

  depends_on = [aws_iam_role.lambda, aws_rds_cluster.main, aws_elasticache_replication_group.main]

  tags = {
    Name        = "${var.project}-procesar-pedido-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Lambda 2: enviar_sms_cocina ──────────────────────────────
resource "aws_lambda_function" "enviar_sms_cocina" {
  #checkov:skip=CKV_AWS_272:Code signing no compatible con ZIPs locales
  #checkov:skip=CKV_AWS_173:KMS para variables de entorno no requerido para despliegue academico
  function_name                  = "${var.project}-enviar-sms-cocina-${var.environment}"
  role                           = aws_iam_role.lambda.arn
  handler                        = "index.handler"
  runtime                        = "nodejs20.x"
  timeout                        = 30
  memory_size                    = 128
  reserved_concurrent_executions = 10

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

  filename         = "${path.module}/../lambdas/enviar_sms_cocina/enviar_sms_cocina.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambdas/enviar_sms_cocina/enviar_sms_cocina.zip")

  tracing_config {
    mode = "Active"
  }

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      ENVIRONMENT     = var.environment
      TELEFONO_COCINA = var.telefono_cocina
    }
  }

  depends_on = [aws_iam_role.lambda]

  tags = {
    Name        = "${var.project}-enviar-sms-cocina-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Lambda 3: actualizar_inventario ──────────────────────────
resource "aws_lambda_function" "actualizar_inventario" {
  #checkov:skip=CKV_AWS_272:Code signing no compatible con ZIPs locales
  #checkov:skip=CKV_AWS_173:KMS para variables de entorno no requerido para despliegue academico
  function_name                  = "${var.project}-actualizar-inventario-${var.environment}"
  role                           = aws_iam_role.lambda.arn
  handler                        = "index.handler"
  runtime                        = "nodejs20.x"
  timeout                        = 60
  memory_size                    = 256
  reserved_concurrent_executions = 10

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

  filename         = "${path.module}/../lambdas/actualizar_inventario/actualizar_inventario.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambdas/actualizar_inventario/actualizar_inventario.zip")

  tracing_config {
    mode = "Active"
  }

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      ENVIRONMENT     = var.environment
      S3_DOCUMENTOS   = aws_s3_bucket.documentos.id
      AURORA_HOST     = aws_rds_cluster.main.endpoint
      AURORA_PORT     = "5432"
      AURORA_DB_NAME  = var.db_name
      AURORA_USER     = var.db_username
      AURORA_PASSWORD = var.db_password
    }
  }

  depends_on = [aws_iam_role.lambda, aws_rds_cluster.main]

  tags = {
    Name        = "${var.project}-actualizar-inventario-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── CloudWatch Log Groups (retención 365 días) ───────────────
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

# ── SQS Event Source Mapping (SQS → Lambda procesar_pedido) ──
resource "aws_lambda_event_source_mapping" "sqs_pedidos" {
  event_source_arn = aws_sqs_queue.pedidos.arn
  function_name    = aws_lambda_function.procesar_pedido.arn
  batch_size       = 10
  enabled          = true
}
