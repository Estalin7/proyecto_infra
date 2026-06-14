output "zone_id" {
  description = "ID de la Hosted Zone creada"
  value       = aws_route53_zone.main.zone_id
}

output "name_servers" {
  description = "Name servers asignados por Route 53 (configurar en el registrador)"
  value       = aws_route53_zone.main.name_servers
}
