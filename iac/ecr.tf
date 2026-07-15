# ============================================================
# ecr.tf
# Crea: Repositorio ECR para imágenes Docker del backend.
# ============================================================

resource "aws_ecr_repository" "crud" {
  name                 = "${var.project}-backend-${var.environment}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.project}-ecr-backend-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Lifecycle policy: mantener solo las últimas 10 imágenes ───
resource "aws_ecr_lifecycle_policy" "crud" {
  repository = aws_ecr_repository.crud.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Mantener solo las ultimas 10 imagenes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}
