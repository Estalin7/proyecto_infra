variable "project" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t3.medium"
}

variable "private_subnet_ids" {
  description = "IDs de las subnets privadas (una instancia por subnet/AZ)"
  type        = list(string)
}

variable "sg_ec2_id" {
  description = "Security Group ID de las EC2"
  type        = string
}

variable "iam_instance_profile_name" {
  description = "Nombre del Instance Profile IAM (para SSM y acceso a S3)"
  type        = string
}

variable "target_group_arn" {
  description = "ARN del Target Group del ALB donde registrar las EC2"
  type        = string
}

variable "app_port" {
  description = "Puerto de la aplicacion Java"
  type        = number
  default     = 8080
}
