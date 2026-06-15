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
