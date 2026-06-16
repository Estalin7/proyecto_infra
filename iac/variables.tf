# ============================================================
# variables.tf
# Variables generales del proyecto. Los valores concretos
# van en terraform.tfvars (no subir secrets al repo).
# ============================================================

variable "project" {
  description = "Nombre del proyecto"
  type        = string
  default     = "restaurante-carloncho"
}

variable "environment" {
  description = "Entorno de despliegue (dev, prod)"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "Region principal de AWS"
  type        = string
  default     = "us-east-2"
}

# ── Dominio ──────────────────────────────────────────────────
variable "domain_name" {
  description = "Dominio principal del proyecto"
  type        = string
  default     = "restaurante-carloncho.com"
}

# ── Red ──────────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR de la VPC"
  type        = string
  default     = "10.2.0.0/16"
}

variable "private_subnets" {
  description = "CIDRs de subnets privadas (una por AZ)"
  type        = list(string)
  default     = ["10.2.1.0/24", "10.2.2.0/24"]
}

variable "public_subnets" {
  description = "CIDRs de subnets publicas (una por AZ)"
  type        = list(string)
  default     = ["10.2.10.0/24", "10.2.11.0/24"]
}

variable "availability_zones" {
  description = "AZs a usar (la primera = writer Aurora, la segunda = reader)"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"]
}

# ── EC2 ──────────────────────────────────────────────────────
variable "ec2_instance_type" {
  description = "Tipo de instancia EC2 para las CRUD"
  type        = string
  default     = "t3.medium"
}

variable "app_port" {
  description = "Puerto de la app Java en las EC2"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Path del health check del backend"
  type        = string
  default     = "/actuator/health"
}

# ── Aurora ───────────────────────────────────────────────────
variable "aurora_instance_class" {
  description = "Clase de instancia Aurora"
  type        = string
  default     = "db.t3.medium"
}

variable "db_name" {
  description = "Nombre de la base de datos en Aurora"
  type        = string
  default     = "restaurantdb"
}

variable "db_username" {
  description = "Usuario administrador de Aurora (PostgreSQL)"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Contrasena del usuario administrador de Aurora"
  type        = string
  sensitive   = true
}

# ── Redis ────────────────────────────────────────────────────
variable "redis_node_type" {
  description = "Tipo de nodo ElastiCache Redis"
  type        = string
  default     = "cache.t3.medium"
}

variable "redis_num_nodes" {
  description = "Numero de nodos Redis"
  type        = number
  default     = 1
}

# ── WAF ──────────────────────────────────────────────────────
variable "waf_rate_limit" {
  description = "Limite de requests por IP en 5 minutos antes de bloquear"
  type        = number
  default     = 2000
}

# ── CloudFront ───────────────────────────────────────────────
variable "cf_price_class" {
  description = "Clase de precio de CloudFront"
  type        = string
  default     = "PriceClass_100"
}

# ── Lambda ───────────────────────────────────────────────────
variable "lambda_artifacts_bucket" {
  description = "Nombre del bucket S3 donde estan los ZIPs de las Lambdas (debe existir antes del apply)"
  type        = string
}

# ── SQS ──────────────────────────────────────────────────────
variable "sqs_visibility_timeout" {
  description = "Visibility timeout de la cola FIFO de pedidos (segundos)"
  type        = number
  default     = 300
}

variable "sqs_max_receive_count" {
  description = "Reintentos antes de enviar a la DLQ"
  type        = number
  default     = 3
}