# ============================================================
# versions.tf
# Terraform version constraint + providers requeridos.
# ============================================================

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }

  # backend "local" {
  #   path = "terraform.tfstate"
  # }

  backend "s3" {
    bucket         = "restaurante-carloncho-tfstate"
    key            = "restaurante-carloncho/terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
  }
}

# ── Provider principal: us-east-2 ────────────────────────────
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# ── Provider alias: us-east-1 (CloudFront, WAF, ACM-CF) ──────
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
