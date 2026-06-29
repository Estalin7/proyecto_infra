# ============================================================
# locals.tf
# Valores calculados y tags comunes reutilizados en todos
# los recursos del root module.
# ============================================================

locals {
  # ARNs construidos por convenio (rompe ciclos iam→sqs e iam→sns→lambda→iam)
  sqs_queue_arn = "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project}-cola-pedidos-${var.environment}.fifo"
  sqs_dlq_arn   = "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project}-dlq-${var.environment}.fifo"
  sns_topic_arn = "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project}-events-${var.environment}"

  # Tags comunes aplicados a todos los recursos
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}
