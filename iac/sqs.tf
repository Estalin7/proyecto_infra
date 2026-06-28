# ============================================================
# sqs.tf
# Crea: DLQ (Dead Letter Queue) + Cola FIFO de pedidos.
# ============================================================

# ── DLQ: mensajes fallidos ────────────────────────────────────
resource "aws_sqs_queue" "dlq" {
  name = "${var.project}-dlq-${var.environment}"

  message_retention_seconds  = 1209600 # 14 dias
  visibility_timeout_seconds = 300
  sqs_managed_sse_enabled    = true

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

  alarm_actions = []

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# ── Cola FIFO: pedidos ────────────────────────────────────────
resource "aws_sqs_queue" "pedidos" {
  name                        = "${var.project}-cola-pedidos-${var.environment}.fifo"
  fifo_queue                  = true
  content_based_deduplication = true

  visibility_timeout_seconds = var.sqs_visibility_timeout
  message_retention_seconds  = 86400  # 1 dia
  max_message_size           = 262144 # 256 KB
  receive_wait_time_seconds  = 20     # Long polling
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.sqs_max_receive_count
  })

  tags = {
    Name        = "${var.project}-cola-pedidos-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_sqs_queue_policy" "pedidos" {
  queue_url = aws_sqs_queue.pedidos.url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowEC2AndLambda"
      Effect = "Allow"
      Principal = {
        AWS = aws_iam_role.lambda.arn
      }
      Action = [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ]
      Resource = aws_sqs_queue.pedidos.arn
    }]
  })
}
