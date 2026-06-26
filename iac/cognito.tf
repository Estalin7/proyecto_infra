# ============================================================
# cognito.tf
# Crea: Cognito User Pool + App Client + dominio de auth.
# Usado por API Gateway como autorización JWT.
# ============================================================

resource "aws_cognito_user_pool" "main" {
  name = "${var.project}-user-pool-${var.environment}"

  username_attributes      = []
  auto_verified_attributes = []

  username_configuration {
    case_sensitive = false
  }

  password_policy {
    minimum_length                   = 8
    require_uppercase                = true
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = false
    temporary_password_validity_days = 7
  }

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

  mfa_configuration = "OFF"

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

resource "aws_cognito_user_pool_client" "main" {
  name         = "${var.project}-app-client-${var.environment}"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  access_token_validity  = 8
  id_token_validity      = 8
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  allowed_oauth_flows_user_pool_client = false
  prevent_user_existence_errors        = "ENABLED"
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project}-auth-${var.environment}"
  user_pool_id = aws_cognito_user_pool.main.id
}
