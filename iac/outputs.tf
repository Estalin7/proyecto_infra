# ============================================================
# outputs.tf
# Outputs principales para verificar el despliegue y conectar
# el frontend / pipelines de CI/CD.
# ============================================================

output "cloudfront_domain_name" {
  description = "Dominio de CloudFront (para configurar el frontend)"
  value       = module.cloudfront.domain_name
}

output "route53_name_servers" {
  description = "Name servers de Route 53 (configurar en el registrador del dominio)"
  value       = module.route53.name_servers
}

output "alb_dns_name" {
  description = "DNS name del ALB"
  value       = module.alb.alb_dns_name
}

output "api_gateway_endpoint" {
  description = "Endpoint del API Gateway"
  value       = module.api_gateway.api_endpoint
}

output "cognito_user_pool_id" {
  description = "ID del User Pool de Cognito"
  value       = module.cognito.user_pool_id
}

output "cognito_client_id" {
  description = "App Client ID de Cognito (para el frontend)"
  value       = module.cognito.client_id
}

output "aurora_cluster_endpoint" {
  description = "Endpoint de escritura de Aurora"
  value       = module.aurora.cluster_endpoint
}

output "aurora_reader_endpoint" {
  description = "Endpoint de lectura de Aurora"
  value       = module.aurora.reader_endpoint
}

output "redis_primary_endpoint" {
  description = "Endpoint primario de ElastiCache Redis"
  value       = module.elasticache.primary_endpoint
}

output "sqs_pedidos_url" {
  description = "URL de la cola SQS FIFO de pedidos"
  value       = module.sqs.queue_url
}

output "dlq_url" {
  description = "URL de la Dead Letter Queue"
  value       = module.dlq.dlq_url
}

output "s3_frontend_bucket" {
  description = "Nombre del bucket S3 del frontend"
  value       = module.s3.frontend_bucket_id
}

output "s3_documentos_bucket" {
  description = "Nombre del bucket S3 de documentos"
  value       = module.s3.documentos_bucket_id
}

output "sns_topic_arn" {
  description = "ARN del SNS Topic de eventos"
  value       = module.sns.topic_arn
}

output "ec2_private_ips" {
  description = "IPs privadas de las EC2 CRUD (para el inventory de Ansible)"
  value       = module.ec2.private_ips
}