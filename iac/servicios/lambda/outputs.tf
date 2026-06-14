output "procesar_pedido_arn" {
  description = "ARN de la Lambda procesar_pedido"
  value       = aws_lambda_function.procesar_pedido.arn
}

output "procesar_inventario_arn" {
  description = "ARN de la Lambda procesar_inventario"
  value       = aws_lambda_function.procesar_inventario.arn
}

output "enviar_sms_cocina_arn" {
  description = "ARN de la Lambda enviar_sms_cocina"
  value       = aws_lambda_function.enviar_sms_cocina.arn
}
