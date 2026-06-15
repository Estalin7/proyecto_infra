output "instance_ids" {
  description = "IDs de las instancias EC2 creadas"
  value       = aws_instance.crud[*].id
}

output "private_ips" {
  description = "IPs privadas de las EC2 (usadas por Ansible en el inventory)"
  value       = aws_instance.crud[*].private_ip
}
