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

output "sg_api_gateway_id" {
  description = "ID del Security Group del VPC Link de API Gateway"
  value       = aws_security_group.api_gateway.id
}

output "sg_vpc_endpoints_id" {
  description = "ID del Security Group de los VPC Endpoints"
  value       = aws_security_group.vpc_endpoints.id
}

output "sg_lambda_id" {
  description = "ID del Security Group de las Lambdas"
  value       = aws_security_group.lambda.id
}