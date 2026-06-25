variable "project" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

variable "s3_documentos_arn" {
  description = "ARN del bucket S3 de documentos"
  type        = string
}

variable "aws_region" {
  description = "Region AWS donde se despliegan los recursos"
  type        = string
}
