output "primary_endpoint" {
  description = "Endpoint del nodo primario Redis (usado por las EC2 y Lambdas)"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "port" {
  description = "Puerto de Redis"
  value       = 6379
}
