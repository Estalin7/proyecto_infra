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

# ── Internet Gateway ─────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project}-igw-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Subnets privadas (una por AZ) ────────────────────────────
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

# ── Subnets públicas (para el ALB) ───────────────────────────
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

# ── Route table privada (sin NAT, solo VPC Endpoints) ────────
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

# ═══════════════════════════════════════════════════════════════
# SECURITY GROUPS
# ═══════════════════════════════════════════════════════════════

resource "aws_security_group" "alb" {
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
    description = "HTTPS saliente hacia ECS"
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

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project}-sg-ecs-tasks-${var.environment}"
  description = "Permite trafico desde el ALB hacia las ECS tasks"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.project}-sg-ecs-tasks-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_security_group" "aurora" {
  name        = "${var.project}-sg-aurora-${var.environment}"
  description = "Permite trafico PostgreSQL desde ECS tasks"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.project}-sg-aurora-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_security_group" "elasticache" {
  name        = "${var.project}-sg-redis-${var.environment}"
  description = "Permite trafico Redis desde ECS tasks"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.project}-sg-redis-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_security_group" "api_gateway" {
  name        = "${var.project}-sg-api-gateway-${var.environment}"
  description = "Permite trafico del VPC Link de API Gateway hacia el ALB"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.project}-sg-api-gateway-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project}-sg-vpc-endpoints-${var.environment}"
  description = "Permite trafico HTTPS desde ECS tasks y Lambda hacia VPC Endpoints"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.project}-sg-vpc-endpoints-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_security_group" "lambda" {
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
# REGLAS CROSS-SG
# ═══════════════════════════════════════════════════════════════

resource "aws_security_group_rule" "ecs_ingress_alb" {
  type                     = "ingress"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ecs_tasks.id
  description              = "Puerto app desde ALB"
}

resource "aws_security_group_rule" "ecs_egress_aurora" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.aurora.id
  security_group_id        = aws_security_group.ecs_tasks.id
  description              = "PostgreSQL saliente hacia Aurora"
}

resource "aws_security_group_rule" "ecs_egress_redis" {
  type                     = "egress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.elasticache.id
  security_group_id        = aws_security_group.ecs_tasks.id
  description              = "Redis saliente hacia ElastiCache"
}

resource "aws_security_group_rule" "ecs_egress_endpoints" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vpc_endpoints.id
  security_group_id        = aws_security_group.ecs_tasks.id
  description              = "HTTPS saliente hacia VPC Interface Endpoints (ECR API, ECR DKR, Logs)"
}

# S3 Gateway Endpoint usa route table (no SG), pero el SG de la tarea
# debe permitir egress a las IPs de S3 para descargar las capas de ECR.
resource "aws_security_group_rule" "ecs_egress_s3" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs_tasks.id
  description       = "HTTPS saliente hacia S3 (capas de imagenes ECR via Gateway Endpoint)"
}

resource "aws_security_group_rule" "aurora_ingress_ecs" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id
  security_group_id        = aws_security_group.aurora.id
  description              = "PostgreSQL desde ECS tasks"
}

resource "aws_security_group_rule" "aurora_ingress_lambda" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda.id
  security_group_id        = aws_security_group.aurora.id
  description              = "PostgreSQL desde Lambda"
}

resource "aws_security_group_rule" "aurora_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["127.0.0.1/32"]
  security_group_id = aws_security_group.aurora.id
  description       = "Sin trafico saliente permitido"
}

resource "aws_security_group_rule" "elasticache_ingress_ecs" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id
  security_group_id        = aws_security_group.elasticache.id
  description              = "Redis desde ECS tasks"
}

resource "aws_security_group_rule" "elasticache_ingress_lambda" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda.id
  security_group_id        = aws_security_group.elasticache.id
  description              = "Redis desde Lambda"
}

resource "aws_security_group_rule" "elasticache_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["127.0.0.1/32"]
  security_group_id = aws_security_group.elasticache.id
  description       = "Sin trafico saliente permitido"
}

resource "aws_security_group_rule" "lambda_egress_aurora" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.aurora.id
  security_group_id        = aws_security_group.lambda.id
  description              = "PostgreSQL hacia Aurora"
}

resource "aws_security_group_rule" "lambda_egress_redis" {
  type                     = "egress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.elasticache.id
  security_group_id        = aws_security_group.lambda.id
  description              = "Redis hacia ElastiCache"
}

resource "aws_security_group_rule" "lambda_egress_endpoints" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vpc_endpoints.id
  security_group_id        = aws_security_group.lambda.id
  description              = "HTTPS hacia VPC Endpoints"
}

resource "aws_security_group_rule" "endpoints_ingress_ecs" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id
  security_group_id        = aws_security_group.vpc_endpoints.id
  description              = "HTTPS desde ECS tasks"
}

resource "aws_security_group_rule" "endpoints_ingress_lambda" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda.id
  security_group_id        = aws_security_group.vpc_endpoints.id
  description              = "HTTPS desde Lambda"
}

resource "aws_security_group_rule" "endpoints_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.vpc_endpoints.id
  description       = "Egress irrestricto requerido para VPC Interface Endpoints"
}

resource "aws_security_group_rule" "alb_from_api_gateway" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.api_gateway.id
  security_group_id        = aws_security_group.alb.id
  description              = "HTTPS desde VPC Link"
}

resource "aws_security_group_rule" "api_gateway_to_alb" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.api_gateway.id
  description              = "Hacia ALB HTTPS"
}

resource "aws_security_group_rule" "alb_egress_ecs" {
  type                     = "egress"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id
  security_group_id        = aws_security_group.alb.id
  description              = "Hacia ECS tasks en puerto app (health checks y trafico)"
}

# ═══════════════════════════════════════════════════════════════
# VPC ENDPOINTS
# ═══════════════════════════════════════════════════════════════

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project}-vpce-ecr-api-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project}-vpce-ecr-dkr-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project}-vpce-logs-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

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



# ═══════════════════════════════════════════════════════════════
# VPC FLOW LOGS
# ═══════════════════════════════════════════════════════════════

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flow-logs/${var.project}-${var.environment}"
  retention_in_days = var.log_retention_days

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