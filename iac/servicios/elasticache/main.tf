terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project}-redis-subnet-group-${var.environment}"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.project}-redis-subnet-group-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${var.project}-redis-${var.environment}"
  description          = "Redis cache para ${var.project} - ${var.environment}"

  node_type            = var.node_type
  port                 = 6379
  parameter_group_name = "default.redis7"
  engine_version       = "7.0"

  num_cache_clusters = var.num_cache_nodes
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [var.sg_elasticache_id]

  # Habilitar encriptacion en transito y en reposo
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  # Habilitar backups automaticos (solo prod)
  snapshot_retention_limit = var.environment == "prod" ? 7 : 0
  snapshot_window          = "03:00-04:00"

  automatic_failover_enabled = var.num_cache_nodes > 1 ? true : false

  tags = {
    Name        = "${var.project}-redis-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}
