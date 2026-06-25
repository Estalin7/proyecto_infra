variable "project" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

variable "domain_name" {
  description = "Dominio principal (ej: mirestaurante.com)"
  type        = string
}

variable "cloudfront_domain_name" {
  description = "Domain name de la distribucion CloudFront (output del modulo cloudfront)"
  type        = string
}

variable "cloudfront_hosted_zone_id" {
  description = "Hosted Zone ID de CloudFront (siempre es Z2FDTNDATAQYW2 para CloudFront)"
  type        = string
  default     = "Z2FDTNDATAQYW2"
}

variable "acm_validation_records" {
  description = "Mapa de registros CNAME para validacion DNS de ACM"
  type = map(object({
    name   = string
    type   = string
    record = string
  }))
  default = {}
}

variable "aws_account_id" {
  description = "ID de la cuenta AWS (para la politica del log group de Route 53)"
  type        = string
}
