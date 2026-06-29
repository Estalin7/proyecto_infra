# ============================================================
# dev.auto.tfvars
# Variables para el entorno de DESARROLLO.
# Terraform carga automáticamente este archivo si usas:
#   terraform workspace select dev
# o si renombras este archivo a terraform.tfvars.
# ============================================================

project     = "restaurante-carloncho"
environment = "dev"
aws_region  = "us-east-2"

domain_name = "dev.restaurant.com"

vpc_cidr           = "10.2.0.0/16"
private_subnets    = ["10.2.1.0/24", "10.2.2.0/24"]
public_subnets     = ["10.2.10.0/24", "10.2.11.0/24"]
availability_zones = ["us-east-2a", "us-east-2b"]

ec2_instance_type = "t3.small"
app_port          = 8080
health_check_path = "/actuator/health"

aurora_instance_class = "db.t3.small"
db_name               = "restaurantdb_dev"

redis_node_type = "cache.t3.micro"

waf_rate_limit   = 5000
cf_price_class   = "PriceClass_100"
cf_geo_whitelist = ["PE", "US"]

sqs_visibility_timeout = 300
sqs_max_receive_count  = 3

cors_allow_origins = [
  "http://localhost:5173",
  "http://localhost:3000",
  "https://dev.restaurant.com"
]
