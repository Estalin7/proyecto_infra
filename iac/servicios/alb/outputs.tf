output "alb_arn" {
  description = "ARN del ALB"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name del ALB"
  value       = aws_lb.main.dns_name
}

output "listener_https_arn" {
  description = "ARN del listener HTTPS (usado por API Gateway VPC Link)"
  value       = aws_lb_listener.https.arn
}

output "target_group_arn" {
  description = "ARN del Target Group de las EC2 CRUD"
  value       = aws_lb_target_group.crud.arn
}
