output "frontend_bucket_id" {
  description = "Nombre del bucket frontend"
  value       = aws_s3_bucket.frontend.id
}

output "frontend_bucket_arn" {
  description = "ARN del bucket frontend"
  value       = aws_s3_bucket.frontend.arn
}

output "frontend_regional_domain_name" {
  description = "Regional domain name del bucket frontend (usado en CloudFront origin)"
  value       = aws_s3_bucket.frontend.bucket_regional_domain_name
}

output "documentos_bucket_id" {
  description = "Nombre del bucket de documentos"
  value       = aws_s3_bucket.documentos.id
}

output "documentos_bucket_arn" {
  description = "ARN del bucket de documentos"
  value       = aws_s3_bucket.documentos.arn
}

output "documentos_regional_domain_name" {
  description = "Regional domain name del bucket de documentos (para failover de CloudFront)"
  value       = aws_s3_bucket.documentos.bucket_regional_domain_name
}
