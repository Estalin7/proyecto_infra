variable "project" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

variable "alarm_sns_topic_arn" {
  description = "ARN del SNS Topic para notificaciones de alarma (opcional)"
  type        = string
  default     = null
}
