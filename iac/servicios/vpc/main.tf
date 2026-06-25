resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project}-vpc-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project}-default-sg-restringido-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Internet Gateway ────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project}-igw-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Subnets privadas (una por AZ) ───────────────────────────
resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = "${var.project}-private-subnet-${var.availability_zones[count.index]}-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Subnets públicas (para el ALB) ──────────────────────────
resource "aws_subnet" "public" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.project}-public-subnet-${var.availability_zones[count.index]}-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Route table pública ──────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project}-rt-public-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ── Route table privada (sin NAT Gateway, solo VPC Endpoints) ─
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project}-rt-private-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ── Security Group: ALB ──────────────────────────────────────
resource "aws_security_group" "alb" {
  #checkov:skip=CKV2_AWS_5:SG adjunto a recursos en modulos externos, falso positivo de analisis estatico entre modulos
  name        = "${var.project}-sg-alb-${var.environment}"
  description = "Permite trafico HTTPS entrante al ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS desde internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTPS saliente hacia EC2"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-sg-alb-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Security Group: EC2 ──────────────────────────────────────
# Sin reglas inline que referencien otros SGs para evitar ciclos.
# Las reglas cross-SG se definen como aws_security_group_rule mas abajo.
resource "aws_security_group" "ec2" {
  #checkov:skip=CKV2_AWS_5:SG adjunto a recursos en modulos externos, falso positivo de analisis estatico entre modulos
  name        = "${var.project}-sg-ec2-${var.environment}"
  description = "Permite trafico desde el ALB hacia las EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Puerto app desde ALB"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  tags = {
    Name        = "${var.project}-sg-ec2-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Security Group: Aurora ───────────────────────────────────
# Sin reglas inline cross-SG para evitar ciclos.
resource "aws_security_group" "aurora" {
  #checkov:skip=CKV2_AWS_5:SG adjunto a recursos en modulos externos, falso positivo de analisis estatico entre modulos
  name        = "${var.project}-sg-aurora-${var.environment}"
  description = "Permite trafico PostgreSQL desde las EC2"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Sin trafico saliente permitido"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["127.0.0.1/32"]
  }

  tags = {
    Name        = "${var.project}-sg-aurora-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Security Group: ElastiCache ──────────────────────────────
# Sin reglas inline cross-SG para evitar ciclos.
resource "aws_security_group" "elasticache" {
  #checkov:skip=CKV2_AWS_5:SG adjunto a recursos en modulos externos, falso positivo de analisis estatico entre modulos
  name        = "${var.project}-sg-redis-${var.environment}"
  description = "Permite trafico Redis desde las EC2"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Sin trafico saliente permitido"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["127.0.0.1/32"]
  }

  tags = {
    Name        = "${var.project}-sg-redis-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Security Group: API Gateway VPC Link ─────────────────────
resource "aws_security_group" "api_gateway" {
  #checkov:skip=CKV2_AWS_5:SG adjunto a recursos en modulos externos, falso positivo de analisis estatico entre modulos
  name        = "${var.project}-sg-api-gateway-${var.environment}"
  description = "Permite trafico del VPC Link de API Gateway hacia el ALB"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.project}-sg-api-gateway-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Security Group: VPC Endpoints ────────────────────────────
# Sin reglas inline cross-SG para evitar ciclos.
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project}-sg-vpc-endpoints-${var.environment}"
  description = "Permite trafico HTTPS desde EC2 y Lambda hacia VPC Endpoints"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.project}-sg-vpc-endpoints-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Security Group: Lambda ────────────────────────────────────
# Sin reglas inline cross-SG para evitar ciclos.
resource "aws_security_group" "lambda" {
  #checkov:skip=CKV2_AWS_5:SG adjunto a recursos en modulos externos, falso positivo de analisis estatico entre modulos
  name        = "${var.project}-sg-lambda-${var.environment}"
  description = "Permite trafico de Lambdas hacia Aurora y Redis"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.project}-sg-lambda-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ═══════════════════════════════════════════════════════════════
# REGLAS CROSS-SG (separadas para romper ciclos de dependencia)
# ═══════════════════════════════════════════════════════════════

# ── EC2 → Aurora (egress) ────────────────────────────────────
resource "aws_security_group_rule" "ec2_to_aurora" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.aurora.id
  security_group_id        = aws_security_group.ec2.id
  description              = "PostgreSQL saliente hacia Aurora"
}

# ── Aurora ← EC2 (ingress) ───────────────────────────────────
resource "aws_security_group_rule" "aurora_from_ec2" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ec2.id
  security_group_id        = aws_security_group.aurora.id
  description              = "PostgreSQL desde EC2"
}

# ── Aurora ← Lambda (ingress) ────────────────────────────────
resource "aws_security_group_rule" "aurora_from_lambda" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda.id
  security_group_id        = aws_security_group.aurora.id
  description              = "PostgreSQL desde Lambda"
}

# ── Lambda → Aurora (egress) ─────────────────────────────────
resource "aws_security_group_rule" "lambda_to_aurora" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.aurora.id
  security_group_id        = aws_security_group.lambda.id
  description              = "PostgreSQL hacia Aurora"
}

# ── ElastiCache ← EC2 (ingress) ──────────────────────────────
resource "aws_security_group_rule" "elasticache_from_ec2" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ec2.id
  security_group_id        = aws_security_group.elasticache.id
  description              = "Redis desde EC2"
}

# ── ElastiCache ← Lambda (ingress) ───────────────────────────
resource "aws_security_group_rule" "elasticache_from_lambda" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda.id
  security_group_id        = aws_security_group.elasticache.id
  description              = "Redis desde Lambda"
}

# ── Lambda → ElastiCache (egress) ────────────────────────────
resource "aws_security_group_rule" "lambda_to_elasticache" {
  type                     = "egress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.elasticache.id
  security_group_id        = aws_security_group.lambda.id
  description              = "Redis hacia ElastiCache"
}

# ── VPC Endpoints ← EC2 (ingress) ────────────────────────────
resource "aws_security_group_rule" "vpc_endpoints_from_ec2" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ec2.id
  security_group_id        = aws_security_group.vpc_endpoints.id
  description              = "HTTPS desde EC2"
}

# ── VPC Endpoints ← Lambda (ingress) ─────────────────────────
resource "aws_security_group_rule" "vpc_endpoints_from_lambda" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda.id
  security_group_id        = aws_security_group.vpc_endpoints.id
  description              = "HTTPS desde Lambda"
}

# ── VPC Endpoints → EC2 (egress) ─────────────────────────────
resource "aws_security_group_rule" "vpc_endpoints_to_ec2" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ec2.id
  security_group_id        = aws_security_group.vpc_endpoints.id
  description              = "HTTPS de respuesta hacia EC2"
}

# ── VPC Endpoints → Lambda (egress) ──────────────────────────
resource "aws_security_group_rule" "vpc_endpoints_to_lambda" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda.id
  security_group_id        = aws_security_group.vpc_endpoints.id
  description              = "HTTPS de respuesta hacia Lambda"
}

# ── Lambda → VPC Endpoints (egress) ──────────────────────────
resource "aws_security_group_rule" "lambda_to_vpc_endpoints" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vpc_endpoints.id
  security_group_id        = aws_security_group.lambda.id
  description              = "HTTPS hacia VPC Endpoints"
}

# ── Regla: ALB acepta HTTPS desde VPC Link ───────────────────
resource "aws_security_group_rule" "alb_from_api_gateway" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.api_gateway.id
  security_group_id        = aws_security_group.alb.id
  description              = "HTTPS desde VPC Link"
}

# ── Regla: VPC Link egress hacia ALB ─────────────────────────
resource "aws_security_group_rule" "api_gateway_to_alb" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.api_gateway.id
  description              = "Hacia ALB HTTPS"
}

# ── VPC Endpoints (Interface) ────────────────────────────────
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project}-vpce-ssm-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── VPC Endpoint: SSM Messages ───────────────────────────────
resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project}-vpce-ssmmessages-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── VPC Endpoint: EC2 Messages (para SSM) ────────────────────
resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project}-vpce-ec2messages-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── VPC Endpoint: S3 Gateway (para descargar artefactos) ─────
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name        = "${var.project}-vpce-s3-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── VPC Endpoint: Secrets Manager ────────────────────────────
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project}-vpce-secretsmanager-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── VPC Endpoint: SNS ────────────────────────────────────────
resource "aws_vpc_endpoint" "sns" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.sns"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project}-vpce-sns-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── KMS key para VPC Flow Logs ────────────────────────────────
resource "aws_kms_key" "vpc_flow_logs" {
  description             = "KMS key para VPC Flow Logs ${var.project}-${var.environment}"
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
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project}-kms-vpc-logs-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flow-logs/${var.project}-${var.environment}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.vpc_flow_logs.arn

  tags = {
    Name        = "${var.project}-vpc-flow-logs-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = "${var.project}-vpc-flow-logs-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${var.project}-vpc-flow-logs-policy-${var.environment}"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = [
        aws_cloudwatch_log_group.vpc_flow_logs.arn,
        "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
      ]
    }]
  })
}

resource "aws_flow_log" "main" {
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn

  tags = {
    Name        = "${var.project}-flow-log-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Data sources ─────────────────────────────────────────────
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
