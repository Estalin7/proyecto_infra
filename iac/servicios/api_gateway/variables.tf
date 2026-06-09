variable "project" {
  description = "Proyecto Restaurante"
  type        = string
}

variable "environment" {
  description = "prod"
  type        = string
}

variable "cognito_client_id" {
  description = "App Client ID de Cognito (output del modulo cognito)"
  type        = string
}

variable "cognito_issuer_url" {
  description = "URL del issuer JWT de Cognito (output del modulo cognito)"
  type        = string
}

variable "alb_listener_arn" {
  description = "ARN del listener HTTPS del ALB (output del modulo alb)"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs de las subnets privadas para el VPC Link"
  type        = list(string)
}

variable "sg_api_gateway_id" {
  description = "Security Group ID para el VPC Link"
  type        = string
}

variable "cors_allow_origins" {
  description = "https://restaurante-carloncho.com"
  type        = list(string)
}
