output "web_acl_arn" {
  description = "ARN del Web ACL (se pasa a CloudFront como web_acl_id)"
  value       = aws_wafv2_web_acl.main.arn
}

output "web_acl_id" {
  description = "ID del Web ACL"
  value       = aws_wafv2_web_acl.main.id
}
