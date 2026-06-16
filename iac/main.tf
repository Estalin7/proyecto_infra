# ── 1. VPC (red + security groups) ───────────────────────────
module "vpc" {
  source = "./servicios/vpc"

  project            = var.project
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  private_subnets    = var.private_subnets
  public_subnets     = var.public_subnets
  availability_zones = var.availability_zones
  app_port           = var.app_port
}

# ── 2. DLQ (debe existir antes que SQS) ──────────────────────
module "dlq" {
  source = "./servicios/dlq"

  project     = var.project
  environment = var.environment
}

# ── 3. IAM (depende de SQS, SNS, S3 -> se resuelve con depends_on) ──
# SQS necesita los roles de IAM para la politica de acceso, e IAM
# necesita los ARNs de SQS/SNS/S3. Para romper el ciclo, IAM se
# declara despues de SQS/S3/SNS pero estos usan placeholders via
# depends_on; aqui usamos el orden real de creacion:
#   dlq -> sqs (con allowed_role_arns) -> iam -> resto
# Por eso iam recibe sqs_queue_arn y s3_documentos_arn directamente,
# y sqs recibe los role arns de iam (con depends_on para forzar orden).

# ── 4. S3 (depende de CloudFront para la politica OAC) ───────
module "s3" {
  source = "./servicios/s3"

  project                     = var.project
  environment                 = var.environment
  cloudfront_distribution_arn = module.cloudfront.distribution_id

  depends_on = [module.cloudfront]
}

# ── 5. ACM (certificados TLS, CloudFront en us-east-1) ───────
module "acm" {
  source = "./servicios/acm"

  project     = var.project
  environment = var.environment
  domain_name = var.domain_name

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}

# ── 6. WAF (scope CLOUDFRONT, en us-east-1) ──────────────────
module "waf" {
  source = "./servicios/waf"

  project     = var.project
  environment = var.environment
  rate_limit  = var.waf_rate_limit

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}

# ── 7. CloudFront (depende de S3, ACM, WAF) ──────────────────
module "cloudfront" {
  source = "./servicios/cloudfront"

  project                         = var.project
  environment                     = var.environment
  domain_name                     = var.domain_name
  s3_bucket_regional_domain_name  = module.s3.frontend_regional_domain_name
  acm_certificate_arn             = module.acm.cert_cloudfront_arn
  waf_acl_arn                     = module.waf.web_acl_arn
  price_class                     = var.cf_price_class

  depends_on = [module.acm, module.waf]
}

# ── 8. Route 53 (depende de CloudFront y ACM) ────────────────
module "route53" {
  source = "./servicios/route53"

  project                   = var.project
  environment               = var.environment
  domain_name               = var.domain_name
  cloudfront_domain_name    = module.cloudfront.domain_name
  cloudfront_hosted_zone_id = module.cloudfront.hosted_zone_id
  acm_validation_records = merge(
    module.acm.cloudfront_validation_records,
    module.acm.alb_validation_records
  )

  depends_on = [module.cloudfront, module.acm]
}

# ── 9. Cognito ────────────────────────────────────────────────
module "cognito" {
  source = "./servicios/cognito"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region
}

# ── 10. ALB (depende de vpc y ACM) ───────────────────────────
module "alb" {
  source = "./servicios/alb"

  project             = var.project
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  sg_alb_id           = module.vpc.sg_alb_id
  acm_certificate_arn = module.acm.cert_alb_arn
  app_port            = var.app_port
  health_check_path   = var.health_check_path
  alb_logs_bucket     = module.s3.alb_logs_bucket

  depends_on = [module.acm]
}

# ── 11. SQS FIFO (depende de DLQ y de los roles IAM) ─────────
module "sqs" {
  source = "./servicios/sqs"

  project            = var.project
  environment        = var.environment
  dlq_arn            = module.dlq.dlq_arn
  visibility_timeout = var.sqs_visibility_timeout
  max_receive_count  = var.sqs_max_receive_count

  depends_on = [module.dlq]
}

# ── 12. IAM (recibe ARNs de SQS, SNS, S3) ────────────────────
module "iam" {
  source = "./servicios/iam"

  project           = var.project
  environment       = var.environment
  sqs_queue_arn     = module.sqs.queue_arn
  sns_topic_arn     = module.sns.topic_arn
  s3_documentos_arn = module.s3.documentos_bucket_arn

  depends_on = [module.sqs, module.s3, module.sns]
}

# ── 13. EC2 (depende de vpc, ALB, IAM) ───────────────────────
module "ec2" {
  source = "./servicios/ec2"

  project                   = var.project
  environment               = var.environment
  instance_type             = var.ec2_instance_type
  private_subnet_ids        = module.vpc.private_subnet_ids
  sg_ec2_id                 = module.vpc.sg_ec2_id
  iam_instance_profile_name = module.iam.ec2_instance_profile_name
  target_group_arn          = module.alb.target_group_arn
  app_port                  = var.app_port

  depends_on = [module.alb, module.iam]
}

# ── 14. ElastiCache Redis ─────────────────────────────────────
module "elasticache" {
  source = "./servicios/elasticache"

  project            = var.project
  environment        = var.environment
  node_type          = var.redis_node_type
  num_cache_nodes    = var.redis_num_nodes
  private_subnet_ids = module.vpc.private_subnet_ids
  sg_elasticache_id  = module.vpc.sg_elasticache_id
}

# ── 15. Aurora PostgreSQL (Multi-AZ) ─────────────────────────
module "aurora" {
  source = "./servicios/aurora"

  project            = var.project
  environment        = var.environment
  instance_class     = var.aurora_instance_class
  db_name            = var.db_name
  db_username        = var.db_username
  db_password        = var.db_password
  private_subnet_ids = module.vpc.private_subnet_ids
  sg_aurora_id       = module.vpc.sg_aurora_id
  availability_zones = var.availability_zones
}

# ── 16. Lambda (depende de IAM, S3, SQS, Aurora, Redis) ──────
module "lambda" {
  source = "./servicios/lambda"

  project              = var.project
  environment          = var.environment
  lambda_role_arn      = module.iam.lambda_role_arn
  artifacts_bucket     = var.lambda_artifacts_bucket
  sqs_pedidos_url      = module.sqs.queue_url
  aurora_host          = module.aurora.cluster_endpoint
  aurora_db_name       = module.aurora.db_name
  redis_host           = module.elasticache.primary_endpoint
  s3_documentos_bucket = module.s3.documentos_bucket_id

  depends_on = [module.iam, module.aurora, module.elasticache, module.sqs]
}

# ── 17. SNS (depende de Lambda) ──────────────────────────────
module "sns" {
  source = "./servicios/sns"

  project                         = var.project
  environment                     = var.environment
  lambda_procesar_pedido_arn      = module.lambda.procesar_pedido_arn
  lambda_procesar_inventario_arn  = module.lambda.procesar_inventario_arn

  depends_on = [module.lambda]
}

# ── 18. API Gateway (depende de Cognito, ALB, vpc) ───────────
module "api_gateway" {
  source = "./servicios/api_gateway"

  project            = var.project
  environment        = var.environment
  cognito_client_id  = module.cognito.client_id
  cognito_issuer_url = module.cognito.issuer_url
  alb_listener_arn   = module.alb.listener_https_arn
  private_subnet_ids = module.vpc.private_subnet_ids
  sg_api_gateway_id  = module.vpc.sg_alb_id
  cors_allow_origins = ["https://${var.domain_name}", "https://www.${var.domain_name}"]

  depends_on = [module.cognito, module.alb]
}
