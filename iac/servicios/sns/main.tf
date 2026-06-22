terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_sns_topic" "main" {
  name = "${var.project}-events-${var.environment}"

  # Habilitar cifrado SSE
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name        = "${var.project}-events-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Suscripcion: Lambda enviar_sms_cocina ────────────────────
resource "aws_sns_topic_subscription" "enviar_sms_cocina" {
  topic_arn = aws_sns_topic.main.arn
  protocol  = "lambda"
  endpoint  = var.lambda_enviar_sms_cocina_arn
}

# ── Suscripcion: Lambda actualizar_inventario ────────────────
resource "aws_sns_topic_subscription" "actualizar_inventario" {
  topic_arn = aws_sns_topic.main.arn
  protocol  = "lambda"
  endpoint  = var.lambda_actualizar_inventario_arn
}

# ── Permiso: SNS puede invocar la Lambda enviar_sms_cocina ───
resource "aws_lambda_permission" "sns_enviar_sms_cocina" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_enviar_sms_cocina_arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.main.arn
}

# ── Permiso: SNS puede invocar la Lambda actualizar_inventario ─
resource "aws_lambda_permission" "sns_actualizar_inventario" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_actualizar_inventario_arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.main.arn
}