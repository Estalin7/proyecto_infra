resource "aws_cognito_user_pool" "main" {
  name = "${var.project}-user-pool-${var.environment}"

  # Login por username (no email)
  username_attributes      = []
  auto_verified_attributes = []

  username_configuration {
    case_sensitive = false
  }

  # Politica de contraseña
  password_policy {
    minimum_length                   = 8
    require_uppercase                = true
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = false
    temporary_password_validity_days = 7
  }

  # Atributos del usuario
  schema {
    name                = "username"
    attribute_data_type = "String"
    mutable             = false
    required            = true

    string_attribute_constraints {
      min_length = 3
      max_length = 50
    }
  }

  # MFA desactivado (se puede activar en el futuro)
  mfa_configuration = "OFF"

  # No enviar emails de verificacion (username, no email)
  account_recovery_setting {
    recovery_mechanism {
      name     = "admin_only"
      priority = 1
    }
  }

  tags = {
    Name        = "${var.project}-user-pool-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── App Client ───────────────────────────────────────────────
resource "aws_cognito_user_pool_client" "main" {
  name         = "${var.project}-app-client-${var.environment}"
  user_pool_id = aws_cognito_user_pool.main.id

  # No secret (cliente publico, SPA / mobile)
  generate_secret = false

  # Flujo de autenticacion: USER_PASSWORD_AUTH para username+password
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  # Duracion de tokens
  access_token_validity  = 8    # horas
  id_token_validity      = 8    # horas
  refresh_token_validity = 30   # dias

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # No OAuth/OIDC flows (autenticacion directa)
  allowed_oauth_flows_user_pool_client = false

  prevent_user_existence_errors = "ENABLED"
}

# ── User Pool Domain (endpoint de Cognito) ───────────────────
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project}-auth-${var.environment}"
  user_pool_id = aws_cognito_user_pool.main.id
}
