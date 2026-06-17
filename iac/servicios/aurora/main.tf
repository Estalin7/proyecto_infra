# ============================================================
# MODULE: aurora
# Crea: Cluster Aurora MySQL Multi-AZ
#   - 1 instancia de escritura (db.t3.medium) en us-east-2a
#   - 1 instancia de lectura  (db.t3.medium) en us-east-2b
#   - Backup automatico 7 dias (prod) / 1 dia (dev)
# ============================================================

resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-aurora-subnet-group-${var.environment}"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.project}-aurora-subnet-group-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_rds_cluster" "main" {
  cluster_identifier     = "${var.project}-aurora-${var.environment}"
  engine                 = "aurora-mysql"
  engine_version         = "8.0.mysql_aurora.3.04.0"
  database_name          = var.db_name
  master_username        = var.db_username
  master_password        = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.sg_aurora_id]

  backup_retention_period = var.environment == "prod" ? 7 : 1
  preferred_backup_window = "02:00-03:00"

  # Proteccion contra borrado accidental en prod
  deletion_protection       = var.environment == "prod" ? true : false
  skip_final_snapshot       = var.environment == "prod" ? false : true
  final_snapshot_identifier = var.environment == "prod" ? "${var.project}-aurora-final-snapshot" : null

  storage_encrypted = true

  # Autenticacion IAM en vez de solo usuario/clave → Fix CKV_AWS_162
  iam_database_authentication_enabled = true

  # Copiar tags a los snapshots de backup → Fix CKV_AWS_313
  copy_tags_to_snapshot = true

  # Exportar logs a CloudWatch → Fix CKV_AWS_324 y CKV_AWS_325
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]

  # Backtracking: permite "rebobinar" el cluster hasta 72h → Fix CKV_AWS_326
  backtrack_window = 259200 # 72 horas en segundos

  tags = {
    Name        = "${var.project}-aurora-cluster-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Instancia escritura (us-east-2a) ─────────────────────────
resource "aws_rds_cluster_instance" "writer" {
  identifier         = "${var.project}-aurora-writer-${var.environment}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  availability_zone          = var.availability_zones[0]
  db_subnet_group_name       = aws_db_subnet_group.main.name
  publicly_accessible        = false
  auto_minor_version_upgrade = true

  tags = {
    Name        = "${var.project}-aurora-writer-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Instancia lectura (us-east-2b) ───────────────────────────
resource "aws_rds_cluster_instance" "reader" {
  identifier         = "${var.project}-aurora-reader-${var.environment}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  availability_zone          = var.availability_zones[1]
  db_subnet_group_name       = aws_db_subnet_group.main.name
  publicly_accessible        = false
  auto_minor_version_upgrade = true

  tags = {
    Name        = "${var.project}-aurora-reader-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}
