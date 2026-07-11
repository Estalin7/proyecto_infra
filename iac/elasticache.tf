resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project}-redis-subnet-group-${var.environment}"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name        = "${var.project}-redis-subnet-group-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}


resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${var.project}-redis-${var.environment}"
  description          = "Redis cache para ${var.project} - ${var.environment}"

  node_type                  = var.redis_node_type
  port                       = 6379
  parameter_group_name       = "default.redis7"
  engine_version             = "7.0"
  num_cache_clusters         = 1
  automatic_failover_enabled = false

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.elasticache.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.redis_auth_token

  auto_minor_version_upgrade = true

  snapshot_retention_limit = var.environment == "prod" ? 7 : 0
  snapshot_window          = "03:00-04:00"


  tags = {
    Name        = "${var.project}-redis-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}
