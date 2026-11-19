variable "aws_region" {
  description = "Región de AWS donde se desplegarán los recursos."
  type        = string
}

variable "project_name" {
  description = "Nombre corto del proyecto, usado para identificar recursos."
  type        = string

  validation {
    condition     = length(trimspace(var.project_name)) > 0
    error_message = "project_name no puede estar vacío."
  }
}

variable "environment" {
  description = "Entorno al que pertenecen los recursos."
  type        = string

  validation {
    condition     = contains(["dev", "test", "stage", "prod"], var.environment)
    error_message = "environment debe ser dev, test, stage o prod."
  }
}

