variable "project" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

variable "instance_class" {
  description = "Clase de instancia Aurora"
  type        = string
  default     = "db.t3.medium"
}

variable "db_name" {
  description = "Nombre de la base de datos inicial"
  type        = string
}

variable "db_username" {
  description = "Usuario administrador de Aurora"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Contrasena del usuario administrador (usar Secrets Manager en prod)"
  type        = string
  sensitive   = true
}

variable "private_subnet_ids" {
  description = "IDs de las subnets privadas"
  type        = list(string)
}

variable "sg_aurora_id" {
  description = "Security Group ID de Aurora"
  type        = string
}

variable "availability_zones" {
  description = "Lista de AZs [writer_az, reader_az]"
  type        = list(string)
}
