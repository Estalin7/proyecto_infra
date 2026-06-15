output "api_id" {
  description = "ID del HTTP API"
  value       = aws_apigatewayv2_api.main.id
}

output "api_endpoint" {
  description = "URL del endpoint del API Gateway"
  value       = aws_apigatewayv2_stage.main.invoke_url
}