variable "project_name" { type = string }
variable "ecs_security_group_id" { type = string }
variable "private_subnet_ids" { type = list(string) }

variable "instance_type" {
  description = "Tipo da instância EC2"
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" { default = 1 }
variable "asg_max_size" { default = 3 }
variable "asg_desired_capacity" { default = 2 }
