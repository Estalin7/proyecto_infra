resource "aws_sns_topic" "main" {
  name = "${var.project}-events-${var.environment}"

  # Cifrado SSE del topic con clave gestionada por AWS → Fix CKV_AWS_26
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name        = "${var.project}-events-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Suscripcion: Lambda procesar_pedido ──────────────────────
resource "aws_sns_topic_subscription" "procesar_pedido" {
  topic_arn = aws_sns_topic.main.arn
  protocol  = "lambda"
  endpoint  = var.lambda_procesar_pedido_arn
}

# ── Suscripcion: Lambda procesar_inventario ──────────────────
resource "aws_sns_topic_subscription" "procesar_inventario" {
  topic_arn = aws_sns_topic.main.arn
  protocol  = "lambda"
  endpoint  = var.lambda_procesar_inventario_arn
}

# ── Permiso: SNS puede invocar la Lambda procesar_pedido ─────
resource "aws_lambda_permission" "sns_procesar_pedido" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_procesar_pedido_arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.main.arn
}

# ── Permiso: SNS puede invocar la Lambda procesar_inventario ─
resource "aws_lambda_permission" "sns_procesar_inventario" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_procesar_inventario_arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.main.arn
}
