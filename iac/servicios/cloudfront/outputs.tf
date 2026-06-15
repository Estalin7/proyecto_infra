output "distribution_id" {
  description = "ID de la distribucion CloudFront"
  value       = aws_cloudfront_distribution.main.id
}

output "domain_name" {
  description = "Domain name de CloudFront (usado en Route 53 alias record)"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "hosted_zone_id" {
  description = "Hosted Zone ID de CloudFront para el alias record de Route 53"
  value       = aws_cloudfront_distribution.main.hosted_zone_id
}

output "oac_id" {
  description = "ID del Origin Access Control (para la politica del bucket S3)"
  value       = aws_cloudfront_origin_access_control.main.id
}
