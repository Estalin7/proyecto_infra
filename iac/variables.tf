variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "restaurant-project"
}

variable "environment" {
  description = "Deployment environment (dev, qa, prod)"
  type        = string
}
