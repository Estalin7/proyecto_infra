terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

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
  map_public_ip_on_launch = true

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
  name        = "${var.project}-sg-alb-${var.environment}"
  description = "Permite trafico HTTP desde VPC Link de API Gateway"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-sg-alb-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Security Group: EC2 (solo acepta tráfico del ALB) ────────
resource "aws_security_group" "ec2" {
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-sg-ec2-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Security Group: Aurora (solo acepta tráfico de EC2) ──────
resource "aws_security_group" "aurora" {
  name        = "${var.project}-sg-aurora-${var.environment}"
  description = "Permite trafico PostgreSQL desde las EC2 y Lambda"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL desde EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  ingress {
    description     = "PostgreSQL desde Lambda"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-sg-aurora-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Security Group: ElastiCache (solo acepta tráfico de EC2) ─
resource "aws_security_group" "elasticache" {
  name        = "${var.project}-sg-redis-${var.environment}"
  description = "Permite trafico Redis desde las EC2 y Lambda"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Redis desde EC2"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  ingress {
    description     = "Redis desde Lambda"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-sg-redis-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Security Group: API Gateway VPC Link ──────────────────────
# El VPC Link debe alcanzar el ALB en la VPC
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

# ── Regla: ALB acepta HTTP desde VPC Link ────────────────────
resource "aws_security_group_rule" "alb_from_api_gateway" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.api_gateway.id
  security_group_id        = aws_security_group.alb.id
  description              = "HTTP desde VPC Link"
}

# ── Regla: VPC Link egress hacia ALB ─────────────────────────
resource "aws_security_group_rule" "api_gateway_to_alb" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.api_gateway.id
  description              = "Hacia ALB HTTP"
}

# ── Security Group: VPC Endpoints (SSM, Secrets Manager, Lambda) ──
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project}-sg-vpc-endpoints-${var.environment}"
  description = "Permite trafico HTTPS desde EC2 y Lambda hacia VPC Endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTPS desde EC2"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  ingress {
    description     = "HTTPS desde Lambda"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  egress {
    description = "Salida libre para respuestas"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-sg-vpc-endpoints-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Security Group: Lambda (para vpc_config) ─────────────────
resource "aws_security_group" "lambda" {
  name        = "${var.project}-sg-lambda-${var.environment}"
  description = "Permite trafico de Lambdas hacia Aurora y Redis"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Salida libre (Lambda necesita acceso a servicios AWS)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-sg-lambda-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ============================================================
# VPC ENDPOINTS para SSM (sin NAT Gateway)
# ============================================================

# ── VPC Endpoint: SSM (Systems Manager) ──────────────────────
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

# ── VPC Endpoint: Secrets Manager (para Lambdas leer credenciales) ──
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

# ── VPC Endpoint: SNS (para Lambdas publicar eventos) ────────────────
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

# ── Data source para obtener la región actual ────────────────
data "aws_region" "current" {}
