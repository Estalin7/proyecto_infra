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

variable "s3_bucket_regional_domain_name" {
  description = "Regional domain name del bucket S3 del frontend (output del modulo s3)"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN del certificado ACM en us-east-1 (output del modulo acm)"
  type        = string
}

variable "waf_acl_arn" {
  description = "ARN del Web ACL de WAF (output del modulo waf). Dejar vacio para deshabilitar."
  type        = string
  default     = null
}

variable "price_class" {
  description = "Clase de precio de CloudFront (PriceClass_100 = solo NA+EU, mas barato)"
  type        = string
  default     = "PriceClass_100"
}

variable "cf_logs_bucket" {
  description = "Bucket S3 donde se guardan los logs de CloudFront"
  type        = string
}

variable "s3_bucket_failover_domain_name" {
  description = "Regional domain name del bucket S3 secundario para failover de CloudFront"
  type        = string
}

variable "cf_geo_whitelist" {
  description = "Lista de paises permitidos en CloudFront"
  type        = list(string)
  default     = ["PE", "US"]
}
