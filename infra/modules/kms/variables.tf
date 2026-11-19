variable "project_name" {
  description = "Nombre corto del proyecto."
  type        = string
}

variable "environment" {
  description = "Entorno al que pertenece la llave."
  type        = string
}

variable "tags" {
  description = "Etiquetas aplicadas a la llave."
  type        = map(string)
  default     = {}
}
