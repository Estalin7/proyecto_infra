variable "project" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue (dev, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block de la VPC"
  type        = string
}

variable "private_subnets" {
  description = "Lista de CIDRs para subnets privadas (una por AZ)"
  type        = list(string)
}

variable "public_subnets" {
  description = "Lista de CIDRs para subnets publicas (una por AZ)"
  type        = list(string)
}

variable "availability_zones" {
  description = "Lista de AZs a usar (ej: [us-east-2a, us-east-2b])"
  type        = list(string)
}

variable "app_port" {
  description = "Puerto en el que corre la app Java en las EC2"
  type        = number
  default     = 8080
}
