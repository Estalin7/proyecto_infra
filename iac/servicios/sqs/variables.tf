variable "project" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

variable "dlq_arn" {
  description = "ARN de la DLQ (output del modulo dlq)"
  type        = string
}

variable "visibility_timeout" {
  description = "Visibility timeout en segundos (debe ser >= timeout de la Lambda consumidora)"
  type        = number
  default     = 300
}

variable "max_receive_count" {
  description = "Numero de reintentos antes de enviar a la DLQ"
  type        = number
  default     = 3
}

variable "allowed_role_arns" {
  description = "Lista de ARNs de roles IAM que pueden producir/consumir mensajes"
  type        = list(string)
}
