variable "bucket_name" {
  description = "Nombre único del bucket S3."
  type        = string
}

variable "kms_key_arn" {
  description = "ARN de la llave KMS usada para cifrar el bucket."
  type        = string
}

variable "tags" {
  description = "Etiquetas aplicadas al bucket."
  type        = map(string)
  default     = {}
}
