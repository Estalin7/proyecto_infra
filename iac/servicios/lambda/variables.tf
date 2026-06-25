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
  description = "Endpoint del cluster Aurora (PostgreSQL)"
  type        = string
}

variable "aurora_db_name" {
  description = "Nombre de la base de datos en Aurora"
  type        = string
}

variable "aurora_username" {
  description = "Usuario de la base de datos Aurora PostgreSQL"
  type        = string
  sensitive   = true
}

variable "aurora_password" {
  description = "Contrasena de la base de datos Aurora PostgreSQL"
  type        = string
  sensitive   = true
}

variable "redis_host" {
  description = "Endpoint del cluster ElastiCache Redis"
  type        = string
}

variable "s3_documentos_bucket" {
  description = "Nombre del bucket S3 de documentos"
  type        = string
}

variable "telefono_cocina" {
  description = "Numero de telefono de cocina en formato E.164 (ej: +51999999999) para recibir SMS via SNS"
  type        = string
}

variable "dlq_arn" {
  description = "ARN de la DLQ para capturar invocaciones fallidas de las Lambdas"
  type        = string
}

variable "private_subnet_ids" {
  description = "Lista de IDs de las subredes privadas donde se desplegaran las Lambdas"
  type        = list(string)
}

variable "sg_lambda_id" {
  description = "ID del Security Group para las funciones Lambda"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN de la llave KMS para encriptar las variables de entorno de Lambda"
  type        = string
}