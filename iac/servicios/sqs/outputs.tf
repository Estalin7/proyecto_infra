output "queue_arn" {
  description = "ARN de la cola FIFO de pedidos"
  value       = aws_sqs_queue.pedidos.arn
}

output "queue_url" {
  description = "URL de la cola FIFO de pedidos"
  value       = aws_sqs_queue.pedidos.url
}

output "queue_name" {
  description = "Nombre de la cola (incluye sufijo .fifo)"
  value       = aws_sqs_queue.pedidos.name
}
