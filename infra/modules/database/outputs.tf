output "cluster_endpoint" {
  description = "Endpoint de escritura del clúster Aurora."
  value       = aws_rds_cluster.main.endpoint
}

output "cluster_arn" {
  description = "ARN del clúster Aurora."
  value       = aws_rds_cluster.main.arn
}

output "security_group_id" {
  description = "ID del security group de Aurora."
  value       = aws_security_group.aurora.id
}

output "master_user_secret_arn" {
  description = "ARN del secreto de Secrets Manager con la contraseña del administrador."
  value       = aws_rds_cluster.main.master_user_secret[0].secret_arn
}

output "vpc_id" {
  description = "ID de la VPC creada para la base de datos."
  value       = aws_vpc.this.id
}
