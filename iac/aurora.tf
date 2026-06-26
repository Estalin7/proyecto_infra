# ============================================================
# aurora.tf
# Crea: Aurora PostgreSQL Multi-AZ
#   - 1 instancia writer (us-east-2a)
#   - 1 instancia reader (us-east-2b)
#   - KMS, backups, IAM auth, CloudWatch logs
# ============================================================

resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-aurora-subnet-group-${var.environment}"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name        = "${var.project}-aurora-subnet-group-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_kms_key" "aurora" {
  description             = "KMS key para Aurora PostgreSQL ${var.project}-${var.environment}"
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
        Sid    = "AllowRDSUse"
        Effect = "Allow"
        Principal = { Service = "rds.amazonaws.com" }
        Action   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project}-kms-aurora-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_rds_cluster" "main" {
  cluster_identifier     = "${var.project}-aurora-${var.environment}"
  engine                 = "aurora-postgresql"
  engine_version         = "16.4"
  database_name          = var.db_name
  master_username        = var.db_username
  master_password        = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.aurora.id]

  backup_retention_period = var.environment == "prod" ? 7 : 1
  preferred_backup_window = "02:00-03:00"

  #checkov:skip=CKV_AWS_139:Proyecto academico, destruccion completa requerida
  #checkov:skip=CKV2_AWS_27:Query logging no requerido para despliegue academico
  #checkov:skip=CKV2_AWS_8:Backup plan de AWS Backup no requerido para despliegue academico
  deletion_protection       = false
  skip_final_snapshot       = var.environment == "prod" ? false : true
  final_snapshot_identifier = var.environment == "prod" ? "${var.project}-aurora-final-snapshot" : null

  storage_encrypted                   = true
  kms_key_id                          = aws_kms_key.aurora.arn
  iam_database_authentication_enabled = true
  copy_tags_to_snapshot               = true

  enabled_cloudwatch_logs_exports = ["postgresql", "instance", "upgrade"]

  tags = {
    Name        = "${var.project}-aurora-cluster-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Instancia escritora (us-east-2a) ─────────────────────────
resource "aws_rds_cluster_instance" "writer" {
  identifier         = "${var.project}-aurora-writer-${var.environment}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = var.aurora_instance_class
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  availability_zone          = var.availability_zones[0]
  db_subnet_group_name       = aws_db_subnet_group.main.name
  publicly_accessible        = false
  auto_minor_version_upgrade = true
  monitoring_interval        = 60
  monitoring_role_arn        = aws_iam_role.rds_enhanced_monitoring.arn

  #checkov:skip=CKV_AWS_353:Performance Insights no requerido para este proyecto academico

  tags = {
    Name        = "${var.project}-aurora-writer-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Instancia lectora (us-east-2b) ───────────────────────────
resource "aws_rds_cluster_instance" "reader" {
  identifier         = "${var.project}-aurora-reader-${var.environment}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = var.aurora_instance_class
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  availability_zone          = var.availability_zones[1]
  db_subnet_group_name       = aws_db_subnet_group.main.name
  publicly_accessible        = false
  auto_minor_version_upgrade = true
  monitoring_interval        = 60
  monitoring_role_arn        = aws_iam_role.rds_enhanced_monitoring.arn

  #checkov:skip=CKV_AWS_353:Performance Insights no requerido para este proyecto academico

  tags = {
    Name        = "${var.project}-aurora-reader-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${var.project}-rds-monitoring-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring_attach" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
