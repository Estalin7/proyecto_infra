output "topic_arn" {
  description = "ARN del SNS Topic"
  value       = aws_sns_topic.main.arn
}

output "topic_name" {
  description = "Nombre del SNS Topic"
  value       = aws_sns_topic.main.name
}
