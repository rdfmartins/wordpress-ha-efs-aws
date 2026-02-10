variable "project_name" {
  description = "Nome do projeto para tagging"
  type        = string
}

variable "creation_token" {
  description = "Token único para garantir idempotência na criação"
  type        = string
}

variable "efs_name" {
  description = "Tag Name do EFS"
  type        = string
  default     = "wordpress-efs-assets"
}

variable "vpc_id" {
  description = "ID da VPC onde o EFS será montado"
  type        = string
}

variable "private_subnet_ids" {
  description = "Lista de IDs das Subnets onde os Mount Targets serão criados"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "ID do Security Group das instâncias ECS para liberar acesso NFS (Chaining)"
  type        = string
}
