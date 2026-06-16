variable "project" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

variable "rate_limit" {
  description = "Maximo de requests por IP en 5 minutos antes de bloquear"
  type        = number
  default     = 2000
}


