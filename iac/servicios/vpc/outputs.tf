output "vpc_id" {
  description = "ID de la VPC principal"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "IDs de las subnets privadas"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "IDs de las subnets publicas"
  value       = aws_subnet.public[*].id
}

output "sg_alb_id" {
  description = "ID del Security Group del ALB"
  value       = aws_security_group.alb.id
}

output "sg_ec2_id" {
  description = "ID del Security Group de las EC2"
  value       = aws_security_group.ec2.id
}

output "sg_aurora_id" {
  description = "ID del Security Group de Aurora"
  value       = aws_security_group.aurora.id
}

output "sg_elasticache_id" {
  description = "ID del Security Group de ElastiCache"
  value       = aws_security_group.elasticache.id
}
