# ── HTTP API ─────────────────────────────────────────────────
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project}-api-${var.environment}"
  protocol_type = "HTTP"
  description   = "API Gateway HTTP para ${var.project} - ${var.environment}"

  cors_configuration {
    allow_origins = var.cors_allow_origins
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }

  tags = {
    Name        = "${var.project}-api-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── JWT Authorizer (valida tokens de Cognito) ────────────────
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.main.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "${var.project}-cognito-authorizer"

  jwt_configuration {
    audience = [var.cognito_client_id]
    issuer   = var.cognito_issuer_url
  }
}

# ── VPC Link (conecta API GW con el ALB en la VPC) ───────────
resource "aws_apigatewayv2_vpc_link" "main" {
  name               = "${var.project}-vpc-link-${var.environment}"
  security_group_ids = [var.sg_api_gateway_id]
  subnet_ids         = var.private_subnet_ids

  tags = {
    Name        = "${var.project}-vpc-link-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── Integracion con el ALB ───────────────────────────────────
resource "aws_apigatewayv2_integration" "alb" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = var.alb_listener_arn
  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
}

# ── Ruta catch-all (proxy a ALB, protegida por Cognito) ──────
resource "aws_apigatewayv2_route" "default" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "ANY /{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.alb.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# ── Stage de despliegue ──────────────────────────────────────
resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = var.environment
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn
  }

  tags = {
    Name        = "${var.project}-api-stage-${var.environment}"
    Project     = var.project
    Environment = var.environment
  }
}

# ── CloudWatch Log Group para el API GW ──────────────────────
resource "aws_cloudwatch_log_group" "api_gw" {
  name              = "/aws/apigateway/${var.project}-${var.environment}"
  retention_in_days = 30

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}
