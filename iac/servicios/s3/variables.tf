variable "project" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

variable "cloudfront_distribution_arn" {
  description = "ARN de la distribucion CloudFront (para la politica OAC del bucket frontend)"
  type        = string
  default     = ""
}
