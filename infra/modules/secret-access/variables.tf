variable "secret_arn" {
  description = "ARN del secreto gestionado por Aurora."
  type        = string
}

variable "allowed_role_arns" {
  description = "ARN de los roles autorizados a leer el secreto."
  type        = list(string)

  validation {
    condition     = length(var.allowed_role_arns) > 0
    error_message = "Debe indicar al menos un rol autorizado."
  }
}

variable "tags" {
  description = "Etiquetas del módulo."
  type        = map(string)
  default     = {}
}
