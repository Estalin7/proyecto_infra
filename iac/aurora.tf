# ============================================================
# aurora.tf
# Crea: Aurora PostgreSQL Multi-AZ
#   - 1 instancia writer (us-east-2a)
#   - 1 instancia reader (us-east-2b)
#   - KMS, backups, IAM auth, CloudWatch logs
#   - Query Logging mediante Cluster Parameter Group
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


# Grupo de parámetros para Query Logging
# CKV2_AWS_27

resource "aws_rds_cluster_parameter_group" "aurora_logging" {
  name        = "${var.project}-aurora-logging-${var.environment}"
  family      = "aurora-postgresql16"
  description = "Parametros de query logging para Aurora PostgreSQL"

  # Registra operaciones DDL como CREATE, ALTER y DROP.
  parameter {
    name         = "log_statement"
    value        = "ddl"
    apply_method = "immediate"
  }

  # Registra consultas que demoren 1000 ms o más.
  parameter {
    name         = "log_min_duration_statement"
    value        = "1000"
    apply_method = "immediate"
  }

  tags = {
    Name        = "${var.project}-aurora-logging-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# Clúster Aurora PostgreSQL

resource "aws_rds_cluster" "main" {
  cluster_identifier = "${var.project}-aurora-${var.environment}"

  engine         = "aurora-postgresql"
  engine_version = "16.4"

  database_name   = var.db_name
  master_username = var.db_username
  master_password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.aurora.id]

  # Asociación con el grupo personalizado de Query Logging.
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora_logging.name

  backup_retention_period = var.environment == "prod" ? 7 : 1
  preferred_backup_window = "02:00-03:00"

  #checkov:skip=CKV2_AWS_8:Backup plan de AWS Backup no requerido para despliegue academico

  #checkov:skip=CKV_AWS_139:Proyecto academico, destruccion completa requerida con terraform destroy
  deletion_protection = false

  skip_final_snapshot       = true
  final_snapshot_identifier = var.environment == "prod" ? "${var.project}-aurora-final-snapshot" : null

  storage_encrypted                   = true
  iam_database_authentication_enabled = true
  copy_tags_to_snapshot               = true

  # Publica el log PostgreSQL en CloudWatch Logs.
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = {
    Name        = "${var.project}-aurora-cluster-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# Instancia escritora — us-east-2a

resource "aws_rds_cluster_instance" "writer" {
  identifier         = "${var.project}-aurora-writer-${var.environment}"
  cluster_identifier = aws_rds_cluster.main.id

  instance_class = var.aurora_instance_class
  engine         = aws_rds_cluster.main.engine
  engine_version = aws_rds_cluster.main.engine_version

  availability_zone    = var.availability_zones[0]
  db_subnet_group_name = aws_db_subnet_group.main.name
  publicly_accessible  = false

  auto_minor_version_upgrade = true

  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_enhanced_monitoring.arn
  performance_insights_enabled = true

  tags = {
    Name        = "${var.project}-aurora-writer-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# Instancia lectora — us-east-2b

resource "aws_rds_cluster_instance" "reader" {
  identifier         = "${var.project}-aurora-reader-${var.environment}"
  cluster_identifier = aws_rds_cluster.main.id

  instance_class = var.aurora_instance_class
  engine         = aws_rds_cluster.main.engine
  engine_version = aws_rds_cluster.main.engine_version

  availability_zone    = var.availability_zones[1]
  db_subnet_group_name = aws_db_subnet_group.main.name
  publicly_accessible  = false

  auto_minor_version_upgrade = true

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn

  #checkov:skip=CKV_AWS_353:Performance Insights no requerido para este proyecto academico

  tags = {
    Name        = "${var.project}-aurora-reader-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# Rol IAM para Enhanced Monitoring de RDS
resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${var.project}-rds-monitoring-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"

        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project}-rds-monitoring-role-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring_attach" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
