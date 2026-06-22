# ============================================================
# MODULE: aurora
# Crea: Cluster Aurora PostgreSQL Multi-AZ
#   - 1 Writer en us-east-2a
#   - 2 Readers: uno en us-east-2b (failover primario, tier 0),
#                otro en us-east-2a (failover secundario, tier 1)
#   - Backup automatico 7 dias (prod) / 1 dia (dev)
# ============================================================

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

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
  cluster_identifier = "${var.project}-aurora-${var.environment}"
  engine             = "aurora-postgresql"
  engine_version     = "15.4"
  database_name      = var.db_name
  master_username    = var.db_username

  # Aurora gestiona la contraseña mediante Secrets Manager
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.sg_aurora_id]

  backup_retention_period = var.environment == "prod" ? 7 : 1
  preferred_backup_window = "02:00-03:00"

  # Proteccion contra borrado accidental en prod
  deletion_protection       = var.environment == "prod" ? true : false
  skip_final_snapshot       = var.environment == "prod" ? false : true
  final_snapshot_identifier = var.environment == "prod" ? "${var.project}-aurora-final-snapshot" : null

  storage_encrypted = true

  # IAM Database Authentication
  iam_database_authentication_enabled = true

  # Habilitar logs (PostgreSQL)
  enabled_cloudwatch_logs_exports = ["postgresql"]

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

  availability_zone    = var.availability_zones[0]
  db_subnet_group_name = aws_db_subnet_group.main.name
  publicly_accessible  = false
  promotion_tier       = 0

  tags = {
    Name        = "${var.project}-aurora-writer-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Instancia lectura 1 (us-east-2b, failover primario) ──────
resource "aws_rds_cluster_instance" "reader_1" {
  identifier         = "${var.project}-aurora-reader-1-${var.environment}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  availability_zone    = var.availability_zones[1]
  db_subnet_group_name = aws_db_subnet_group.main.name
  publicly_accessible  = false
  promotion_tier       = 0

  tags = {
    Name        = "${var.project}-aurora-reader-1-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Instancia lectura 2 (us-east-2a, failover secundario) ────
resource "aws_rds_cluster_instance" "reader_2" {
  identifier         = "${var.project}-aurora-reader-2-${var.environment}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  availability_zone    = var.availability_zones[0]
  db_subnet_group_name = aws_db_subnet_group.main.name
  publicly_accessible  = false
  promotion_tier       = 1

  tags = {
    Name        = "${var.project}-aurora-reader-2-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}
