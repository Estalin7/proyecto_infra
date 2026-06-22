variable "project" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

variable "aws_region" {
  description = "Region AWS donde esta el User Pool"
  type        = string
  default     = "us-east-2"
}
