resource "aws_lambda_function" "procesar_pedido" {
  function_name = "${var.project}-procesar-pedido-${var.environment}"
  role          = var.lambda_role_arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = 60
  memory_size   = 256

  s3_bucket = var.artifacts_bucket
  s3_key    = "lambdas/procesar_pedido.zip"

  # Habilitar X-Ray tracing → Fix CKV_AWS_50
  tracing_config {
    mode = "Active"
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
  function_name = "${var.project}-enviar-sms-cocina-${var.environment}"
  role          = var.lambda_role_arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = 30
  memory_size   = 128

  s3_bucket = var.artifacts_bucket
  s3_key    = "lambdas/enviar_sms_cocina.zip"

  # Habilitar X-Ray tracing → Fix CKV_AWS_50
  tracing_config {
    mode = "Active"
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
  function_name = "${var.project}-actualizar-inventario-${var.environment}"
  role          = var.lambda_role_arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = 60
  memory_size   = 256

  s3_bucket = var.artifacts_bucket
  s3_key    = "lambdas/actualizar_inventario.zip"

  # Habilitar X-Ray tracing → Fix CKV_AWS_50
  tracing_config {
    mode = "Active"
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

# ── CloudWatch Log Groups (retencion 365 dias) → Fix CKV_AWS_338 ─
resource "aws_cloudwatch_log_group" "procesar_pedido" {
  name              = "/aws/lambda/${aws_lambda_function.procesar_pedido.function_name}"
  retention_in_days = 365
}

resource "aws_cloudwatch_log_group" "enviar_sms_cocina" {
  name              = "/aws/lambda/${aws_lambda_function.enviar_sms_cocina.function_name}"
  retention_in_days = 365
}

resource "aws_cloudwatch_log_group" "actualizar_inventario" {
  name              = "/aws/lambda/${aws_lambda_function.actualizar_inventario.function_name}"
  retention_in_days = 365
}