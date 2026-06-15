# ============================================================
# backend.tf
# Backend LOCAL: el estado se guarda en terraform.tfstate
# dentro de esta misma carpeta.
#
# IMPORTANTE: agregar terraform.tfstate* a .gitignore para
# no subir el estado (puede contener datos sensibles como
# contrasenas de Aurora).
#
# Cuando tengas creado el bucket S3 + tabla DynamoDB, descomenta
# el bloque de abajo y borra/comenta el backend "local".
# ============================================================

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }

  # backend "s3" {
  #   bucket         = "restaurante-carloncho-tfstate"
  #   key            = "restaurante-carloncho/terraform.tfstate"
  #   region         = "us-east-2"
  #   encrypt        = true
  #   dynamodb_table = "restaurante-carloncho-tf-lock"
  # }
}