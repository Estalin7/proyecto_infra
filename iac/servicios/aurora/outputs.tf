output "cluster_endpoint" {
  description = "Endpoint de escritura del cluster Aurora"
  value       = aws_rds_cluster.main.endpoint
}

output "reader_endpoint" {
  description = "Endpoint de lectura del cluster Aurora"
  value       = aws_rds_cluster.main.reader_endpoint
}

output "cluster_identifier" {
  description = "Identificador del cluster Aurora"
  value       = aws_rds_cluster.main.cluster_identifier
}

output "db_name" {
  description = "Nombre de la base de datos"
  value       = aws_rds_cluster.main.database_name
}

output "master_user_secret_arn" {
  description = "ARN del secreto de Secrets Manager que contiene las credenciales del usuario master"
  value       = aws_rds_cluster.main.master_user_secret[0].secret_arn
  sensitive   = true
}
