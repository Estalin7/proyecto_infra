# ============================================================
# prod.auto.tfvars
# Variables para el entorno de PRODUCCIÓN.
# Terraform carga automáticamente este archivo.
# NUNCA subir al repositorio (está en .gitignore).
# ============================================================

project     = "restaurante-carloncho"
environment = "prod"
aws_region  = "us-east-2"

# ── Dominio ──────────────────────────────────────────────────
domain_name = "restaurant.com"

# ── Red ──────────────────────────────────────────────────────
vpc_cidr           = "10.2.0.0/16"
private_subnets    = ["10.2.1.0/24", "10.2.2.0/24"]
public_subnets     = ["10.2.10.0/24", "10.2.11.0/24"]
availability_zones = ["us-east-2a", "us-east-2b"]

# ── EC2 ──────────────────────────────────────────────────────
ec2_instance_type = "t3.medium"
app_port          = 8080
health_check_path = "/actuator/health"

# ── Aurora ───────────────────────────────────────────────────
aurora_instance_class = "db.t3.medium"
db_name               = "restaurantdb"
# db_username y db_password → NO poner aquí, usar TF_VAR_ env vars

# ── Redis ────────────────────────────────────────────────────
redis_node_type = "cache.t3.medium"
# redis_auth_token → NO poner aquí, usar TF_VAR_ env vars

# ── WAF ──────────────────────────────────────────────────────
waf_rate_limit = 2000

# ── CloudFront ───────────────────────────────────────────────
cf_price_class  = "PriceClass_100"
cf_geo_whitelist = ["PE", "US", "ES"]

# ── SQS ──────────────────────────────────────────────────────
sqs_visibility_timeout = 300
sqs_max_receive_count  = 3

# ── Lambda / SNS ─────────────────────────────────────────────
# telefono_cocina → NO poner aquí, usar TF_VAR_ env vars

# ── API Gateway CORS ─────────────────────────────────────────
cors_allow_origins = [
  "https://restaurant.com",
  "https://www.restaurant.com"
]
