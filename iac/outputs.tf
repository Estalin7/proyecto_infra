# ============================================================
# outputs.tf
# Outputs principales para verificar el despliegue y conectar
# el frontend / pipelines de CI/CD.
# ============================================================

output "cloudfront_domain_name" {
  description = "Dominio de CloudFront (para configurar el frontend)"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "route53_name_servers" {
  description = "Name servers de Route 53 (configurar en el registrador del dominio)"
  value       = aws_route53_zone.main.name_servers
}

output "alb_dns_name" {
  description = "DNS name del ALB interno"
  value       = aws_lb.main.dns_name
}

output "api_gateway_endpoint" {
  description = "Endpoint del API Gateway"
  value       = aws_apigatewayv2_stage.main.invoke_url
}

output "cognito_user_pool_id" {
  description = "ID del User Pool de Cognito"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_client_id" {
  description = "App Client ID de Cognito (para el frontend)"
  value       = aws_cognito_user_pool_client.main.id
}

output "aurora_cluster_endpoint" {
  description = "Endpoint de escritura de Aurora"
  value       = aws_rds_cluster.main.endpoint
  sensitive   = true
}

output "aurora_reader_endpoint" {
  description = "Endpoint de lectura de Aurora"
  value       = aws_rds_cluster.main.reader_endpoint
  sensitive   = true
}

output "redis_primary_endpoint" {
  description = "Endpoint primario de ElastiCache Redis"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
  sensitive   = true
}

output "sqs_pedidos_url" {
  description = "URL de la cola SQS FIFO de pedidos"
  value       = aws_sqs_queue.pedidos.url
}

output "dlq_url" {
  description = "URL de la Dead Letter Queue"
  value       = aws_sqs_queue.dlq.url
}

output "s3_frontend_bucket" {
  description = "Nombre del bucket S3 del frontend"
  value       = aws_s3_bucket.frontend.id
}

output "s3_documentos_bucket" {
  description = "Nombre del bucket S3 de documentos"
  value       = aws_s3_bucket.documentos.id
}

output "sns_topic_arn" {
  description = "ARN del SNS Topic de eventos"
  value       = aws_sns_topic.main.arn
}

output "ec2_private_ips" {
  description = "IPs privadas de las EC2 CRUD (para el inventario de Ansible)"
  value       = aws_instance.crud[*].private_ip
}
