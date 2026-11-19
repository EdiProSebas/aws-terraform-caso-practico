output "secret_arn" {
  description = "ARN del secreto protegido."
  value       = aws_secretsmanager_secret_policy.this.secret_arn
}
