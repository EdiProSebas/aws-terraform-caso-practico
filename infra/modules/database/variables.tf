variable "kms_key_arn" {
  description = "ARN de la llave KMS para cifrar Aurora."
  type        = string
}

variable "tags" {
  description = "Etiquetas aplicadas a los recursos de base de datos."
  type        = map(string)
  default     = {}
}

variable "project_name" {
  description = "Nombre corto del proyecto."
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue."
  type        = string
}

variable "db_name" {
  description = "Nombre de la base de datos inicial."
  type        = string
}

variable "master_username" {
  description = "Usuario administrador de Aurora."
  type        = string
}

variable "backup_retention_period" {
  description = "Días de retención de backups automatizados."
  type        = number
  default     = 7
}


variable "vpc_cidr" {
  description = "Bloque CIDR de la VPC de la práctica."
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "Bloques CIDR para las subnets privadas de Aurora."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "engine_version" {
  description = "Versión de Aurora PostgreSQL."
  type        = string
}

variable "instance_class" {
  description = "Clase de instancia de Aurora (por ejemplo, el tamaño de cómputo)."
  type        = string
}

variable "allowed_security_group_ids" {
  description = "Security groups autorizados a conectarse a Aurora por el puerto 5432 (por ejemplo, el de los servicios ECS)."
  type        = list(string)
  default     = []
}


variable "deletion_protection" {
  description = "Protege el clúster contra eliminación accidental."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Si es true, no se crea snapshot final al destruir el clúster."
  type        = bool
  default     = false
}
