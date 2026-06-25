output "ec2_role_arn" {
  description = "ARN del rol IAM de las EC2"
  value       = aws_iam_role.ec2.arn
}

output "ec2_instance_profile_name" {
  description = "Nombre del Instance Profile para las EC2"
  value       = aws_iam_instance_profile.ec2.name
}

output "lambda_role_arn" {
  description = "ARN del rol IAM para las Lambdas"
  value       = aws_iam_role.lambda.arn
}

output "lambda_sqs_role_arn" {
  description = "Lista de ARNs de roles (EC2 + Lambda) que pueden usar la cola SQS"
  value       = [aws_iam_role.ec2.arn, aws_iam_role.lambda.arn]
}
