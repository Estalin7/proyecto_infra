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

variable "private_subnet_ids" {
  description = "IDs de las subnets privadas donde se despliega el ALB interno"
  type        = list(string)
}

variable "sg_alb_id" {
  description = "Security Group ID del ALB"
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

variable "s3_logs_bucket_id" {
  description = "ID del bucket S3 para almacenar los logs del ALB"
  type        = string
}
