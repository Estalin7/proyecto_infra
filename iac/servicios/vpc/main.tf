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

# ── Security Group: ALB ──────────────────────────────────────
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

  ingress {
    description = "HTTP (redireccion a HTTPS)"
    from_port   = 80
    to_port     = 80
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
    description     = "PostgreSQL saliente hacia Aurora"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.aurora.id]
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
  description = "Permite trafico MySQL desde las EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL desde EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

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

# ── Security Group: ElastiCache (solo acepta tráfico de EC2) ─
resource "aws_security_group" "elasticache" {
  name        = "${var.project}-sg-redis-${var.environment}"
  description = "Permite trafico Redis desde las EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Redis desde EC2"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

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
