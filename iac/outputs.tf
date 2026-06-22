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

# ── Cognito ──────────────────────────────────────────────────
output "cognito_issuer_url" {
  description = "URL del issuer JWT de Cognito (para el API Gateway Authorizer)"
  value       = module.cognito.issuer_url
}

output "cognito_user_pool_domain" {
  description = "Dominio del User Pool de Cognito"
  value       = module.cognito.user_pool_domain
}

# ── SQS ──────────────────────────────────────────────────────
output "sqs_pedidos_arn" {
  description = "ARN de la cola SQS FIFO de pedidos"
  value       = module.sqs.queue_arn
}

# ── Lambda ───────────────────────────────────────────────────
output "lambda_procesar_pedido_arn" {
  description = "ARN de la Lambda procesar_pedido"
  value       = module.lambda.procesar_pedido_arn
}

output "lambda_actualizar_inventario_arn" {
  description = "ARN de la Lambda actualizar_inventario"
  value       = module.lambda.actualizar_inventario_arn
}

output "lambda_enviar_sms_cocina_arn" {
  description = "ARN de la Lambda enviar_sms_cocina"
  value       = module.lambda.enviar_sms_cocina_arn
}

# ── IAM ──────────────────────────────────────────────────────
output "iam_ec2_role_arn" {
  description = "ARN del rol IAM de las EC2"
  value       = module.iam.ec2_role_arn
}

output "iam_lambda_role_arn" {
  description = "ARN del rol IAM de las Lambdas"
  value       = module.iam.lambda_role_arn
}

# ── ALB ──────────────────────────────────────────────────────
output "alb_listener_http_arn" {
  description = "ARN del listener HTTP del ALB (para API Gateway)"
  value       = module.alb.listener_http_arn
}