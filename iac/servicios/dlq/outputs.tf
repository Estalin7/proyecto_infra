# Outputs del módulo DLQ
output "dlq_arn" {
  description = "ARN de la DLQ (se pasa al modulo sqs para la redrive policy)"
  value       = aws_sqs_queue.dlq.arn
}

output "dlq_url" {
  description = "URL de la DLQ"
  value       = aws_sqs_queue.dlq.url
}
