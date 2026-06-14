variable "project" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs de las subnets publicas donde se despliega el ALB"
  type        = list(string)
}

variable "sg_alb_id" {
  description = "Security Group ID del ALB"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN del certificado ACM para el listener HTTPS"
  type        = string
}

variable "app_port" {
  description = "Puerto de la aplicacion en las EC2"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Path del health check del backend"
  type        = string
  default     = "/actuator/health"
}
