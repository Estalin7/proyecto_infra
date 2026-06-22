output "cert_cloudfront_arn" {
  description = "ARN del certificado ACM para CloudFront"
  value       = aws_acm_certificate_validation.cloudfront.certificate_arn
}

# Expone los registros CNAME necesarios para validacion DNS
# El modulo route53 los consumira para crear los registros
output "cloudfront_validation_records" {
  description = "Registros DNS para validar el certificado de CloudFront"
  value = {
    for dvo in aws_acm_certificate.cloudfront.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }
}
