resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project}-redis-subnet-group-${var.environment}"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.project}-redis-subnet-group-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}
resource "aws_kms_key" "elasticache" {
  description             = "KMS key para ElastiCache Redis ${var.project}-${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowElastiCacheUse"
        Effect = "Allow"
        Principal = {
          Service = "elasticache.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project}-kms-redis-${var.environment}"
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

  num_cache_clusters = 2
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [var.sg_elasticache_id]

  # Habilitar encriptacion en transito y en reposo
  at_rest_encryption_enabled = true
  kms_key_id                 = aws_kms_key.elasticache.arn
  transit_encryption_enabled = true
  auth_token                 = var.redis_auth_token

  # Actualizaciones automaticas de version menor → Fix CKV_AWS_191
  auto_minor_version_upgrade = true

  # Habilitar backups automaticos (solo prod)
  snapshot_retention_limit = var.environment == "prod" ? 7 : 0
  snapshot_window          = "03:00-04:00"

  automatic_failover_enabled = true

  tags = {
    Name        = "${var.project}-redis-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

data "aws_caller_identity" "current" {}