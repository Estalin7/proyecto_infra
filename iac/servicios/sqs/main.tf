terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_sqs_queue" "pedidos" {
  name                        = "${var.project}-cola-pedidos-${var.environment}.fifo"
  fifo_queue                  = true
  content_based_deduplication = true

  visibility_timeout_seconds = var.visibility_timeout
  message_retention_seconds  = 86400  # 1 dia
  max_message_size           = 262144 # 256 KB
  receive_wait_time_seconds  = 20     # Long polling

  # Cifrado SSE-SQS
  sqs_managed_sse_enabled = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = var.dlq_arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = {
    Name        = "${var.project}-cola-pedidos-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Politica de acceso: solo las EC2 y Lambdas pueden usar la cola ──
resource "aws_sqs_queue_policy" "pedidos" {
  count     = length(var.allowed_role_arns) > 0 ? 1 : 0
  queue_url = aws_sqs_queue.pedidos.url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEC2AndLambda"
        Effect = "Allow"
        Principal = {
          AWS = var.allowed_role_arns
        }
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.pedidos.arn
      }
    ]
  })
}
