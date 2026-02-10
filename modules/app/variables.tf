variable "project_name" { type = string }
variable "region" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "alb_security_group_id" { type = string }
variable "cluster_id" { type = string }
variable "efs_id" { type = string }

variable "ssm_db_host_arn" { type = string }
variable "ssm_db_user_arn" { type = string }
variable "ssm_db_pass_arn" { type = string }
variable "ssm_db_name_arn" { type = string }
