variable "project" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

variable "lambda_role_arn" {
  description = "ARN del rol IAM para las Lambdas (output del modulo iam)"
  type        = string
}

variable "artifacts_bucket" {
  description = "Nombre del bucket S3 donde estan los ZIPs de las Lambdas"
  type        = string
}

variable "sqs_pedidos_url" {
  description = "URL de la cola SQS FIFO de pedidos"
  type        = string
}

variable "aurora_host" {
  description = "Endpoint del cluster Aurora"
  type        = string
}

variable "aurora_db_name" {
  description = "Nombre de la base de datos en Aurora"
  type        = string
}

variable "redis_host" {
  description = "Endpoint del cluster ElastiCache Redis"
  type        = string
}

variable "s3_documentos_bucket" {
  description = "Nombre del bucket S3 de documentos"
  type        = string
}
