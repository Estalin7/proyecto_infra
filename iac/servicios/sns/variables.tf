variable "project" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

variable "lambda_enviar_sms_cocina_arn" {
  description = "ARN de la Lambda enviar_sms_cocina (output del modulo lambda)"
  type        = string
}

variable "lambda_actualizar_inventario_arn" {
  description = "ARN de la Lambda actualizar_inventario (output del modulo lambda)"
  type        = string
}
