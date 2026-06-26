# ============================================================
# sns.tf
# Crea: SNS Topic + suscripciones Lambda + permisos de invocación
# ============================================================

resource "aws_sns_topic" "main" {
  name              = "${var.project}-events-${var.environment}"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name        = "${var.project}-events-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_sns_topic_subscription" "procesar_pedido" {
  topic_arn = aws_sns_topic.main.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.procesar_pedido.arn
}

resource "aws_sns_topic_subscription" "procesar_inventario" {
  topic_arn = aws_sns_topic.main.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.actualizar_inventario.arn
}

resource "aws_lambda_permission" "sns_procesar_pedido" {
  statement_id  = "AllowSNSInvokeProcesarPedido"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.procesar_pedido.arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.main.arn
}

resource "aws_lambda_permission" "sns_procesar_inventario" {
  statement_id  = "AllowSNSInvokeActualizarInventario"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.actualizar_inventario.arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.main.arn
}
