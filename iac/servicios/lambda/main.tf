# ============================================================
# MODULE: lambda
# Crea: 3 funciones Lambda
#   1. procesar_pedido       → triggered por SNS, llama a enviar_sms_cocina
#   2. enviar_sms_cocina      → invocada por procesar_pedido (SNS SMS)
#   3. actualizar_inventario  → triggered por SNS, descuenta stock y guarda en S3
#
# Los ZIPs de codigo se despliegan via S3 (bucket de artefactos).
# Base de datos: Aurora PostgreSQL (libreria pg en runtime nodejs)
# ============================================================

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# ── Lambda 1: procesar_pedido ────────────────────────────────
resource "aws_lambda_function" "procesar_pedido" {
  function_name = "${var.project}-procesar-pedido-${var.environment}"
  role          = var.lambda_role_arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = 60
  memory_size   = 256

  s3_bucket = var.artifacts_bucket
  s3_key    = "lambdas/procesar_pedido.zip"

  # Configuración VPC para acceder a Aurora y Redis
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.sg_lambda_id]
  }

  environment {
    variables = {
      NODE_EXTRA_CA_CERTS = "/var/runtime/ca-cert.pem"
      ENVIRONMENT         = var.environment
      SNS_TOPIC_ARN       = var.sns_topic_arn
      SQS_PEDIDOS_URL     = var.sqs_pedidos_url
      AURORA_HOST         = var.aurora_host
      AURORA_PORT         = "5432"
      AURORA_DB_NAME      = var.aurora_db_name
      AURORA_USER         = var.aurora_username
      AURORA_SECRET_ARN   = var.aurora_secret_arn
      REDIS_HOST          = var.redis_host
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
  function_name = "${var.project}-enviar-sms-cocina-${var.environment}"
  role          = var.lambda_role_arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = 30
  memory_size   = 128

  s3_bucket = var.artifacts_bucket
  s3_key    = "lambdas/enviar_sms_cocina.zip"

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
  function_name = "${var.project}-actualizar-inventario-${var.environment}"
  role          = var.lambda_role_arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = 60
  memory_size   = 256

  s3_bucket = var.artifacts_bucket
  s3_key    = "lambdas/actualizar_inventario.zip"

  # Configuración VPC para acceder a Aurora
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.sg_lambda_id]
  }

  environment {
    variables = {
      NODE_EXTRA_CA_CERTS = "/var/runtime/ca-cert.pem"
      ENVIRONMENT         = var.environment
      S3_DOCUMENTOS       = var.s3_documentos_bucket
      AURORA_HOST         = var.aurora_host
      AURORA_PORT         = "5432"
      AURORA_DB_NAME      = var.aurora_db_name
      AURORA_USER         = var.aurora_username
      AURORA_SECRET_ARN   = var.aurora_secret_arn
    }
  }

  tags = {
    Name        = "${var.project}-actualizar-inventario-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── CloudWatch Log Groups (retencion 30 dias) ────────────────
resource "aws_cloudwatch_log_group" "procesar_pedido" {
  name              = "/aws/lambda/${aws_lambda_function.procesar_pedido.function_name}"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "enviar_sms_cocina" {
  name              = "/aws/lambda/${aws_lambda_function.enviar_sms_cocina.function_name}"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "actualizar_inventario" {
  name              = "/aws/lambda/${aws_lambda_function.actualizar_inventario.function_name}"
  retention_in_days = 30
}

# ============================================================
# EVENT SOURCE MAPPING: SQS → Lambda procesar_pedido
# ============================================================

resource "aws_lambda_event_source_mapping" "sqs_to_procesar_pedido" {
  event_source_arn = var.sqs_queue_arn
  function_name    = aws_lambda_function.procesar_pedido.arn
  batch_size       = 1
  enabled          = true

  # Configurar retry y manejo de errores
  function_response_types = ["ReportBatchItemFailures"]

  scaling_config {
    maximum_concurrency = 5
  }
}