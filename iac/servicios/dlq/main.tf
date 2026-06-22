# ============================================================
# MODULE: dlq
# Crea: cola SQS FIFO que actua como Dead Letter Queue.
#       Recibe mensajes fallidos de la SQS FIFO de pedidos
#       tras 3 reintentos fallidos.
#       IMPORTANTE: Debe ser FIFO porque la cola principal es FIFO.
# ============================================================

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_sqs_queue" "dlq" {
  name       = "${var.project}-dlq-${var.environment}.fifo"
  fifo_queue = true

  # Retener mensajes fallidos 14 dias para revision/reintento manual
  message_retention_seconds = 1209600 # 14 dias

  # Visibility timeout mayor que el de la cola principal (evita reprocessing)
  visibility_timeout_seconds = 300

  # Cifrado SSE-SQS
  sqs_managed_sse_enabled = true

  tags = {
    Name        = "${var.project}-dlq-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Alarma CloudWatch: avisa si hay mensajes en la DLQ ──────
resource "aws_cloudwatch_metric_alarm" "dlq_not_empty" {
  alarm_name          = "${var.project}-dlq-mensajes-${var.environment}"
  alarm_description   = "Hay mensajes fallidos en la DLQ. Revisar pedidos no procesados."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }

  alarm_actions = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}
