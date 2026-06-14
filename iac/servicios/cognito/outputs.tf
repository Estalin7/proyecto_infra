output "user_pool_id" {
  description = "ID del User Pool"
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "ARN del User Pool"
  value       = aws_cognito_user_pool.main.arn
}

output "client_id" {
  description = "ID del App Client (se usa en el frontend para hacer login)"
  value       = aws_cognito_user_pool_client.main.id
}

output "issuer_url" {
  description = "URL del issuer JWT para configurar el Authorizer en API Gateway"
  value       = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.main.id}"
}

variable "aws_region" {
  description = "Region AWS donde esta el User Pool"
  type        = string
  default     = "us-east-2"
}
