resource "aws_sns_topic" "main" {
  name = "${var.project}-events-${var.environment}"

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

# ── Suscripcion: Lambda actualizar_inventario ────────────────
resource "aws_sns_topic_subscription" "actualizar_inventario" {
  topic_arn = aws_sns_topic.main.arn
  protocol  = "lambda"
  endpoint  = var.lambda_actualizar_inventario_arn
}

# ── Permiso: SNS puede invocar la Lambda procesar_pedido ─────
resource "aws_lambda_permission" "sns_procesar_pedido" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_procesar_pedido_arn
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