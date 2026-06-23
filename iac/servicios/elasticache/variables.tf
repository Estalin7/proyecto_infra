variable "project" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

variable "node_type" {
  description = "Tipo de nodo Redis"
  type        = string
  default     = "cache.t3.medium"
}

variable "num_cache_nodes" {
  description = "Numero de nodos (1 = sin replicacion, 2+ = con replica)"
  type        = number
  default     = 1
}

variable "private_subnet_ids" {
  description = "IDs de las subnets privadas"
  type        = list(string)
}

variable "sg_elasticache_id" {
  description = "Security Group ID de ElastiCache"
  type        = string
}


variable "redis_auth_token" {
  description = "Token de autenticacion para Redis (minimo 16 caracteres, maximo 128)"
  type        = string
  sensitive   = true
}