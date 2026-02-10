variable "project_name" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "ecs_security_group_id" { type = string }

variable "db_name" {
  description = "Nome do Database schema"
  type        = string
  default     = "wordpress"
}

variable "db_user" {
  description = "Usuario admin do banco"
  type        = string
  default     = "admin"
}
