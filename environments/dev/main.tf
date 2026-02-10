# --- Providers ---
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "random" {}

# --- Variáveis ---
variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "ha-wordpress"
}

variable "region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

# --- Módulo Network ---
module "network" {
  source       = "../../modules/network"
  project_name = var.project_name
  vpc_cidr     = "10.0.0.0/16"
}

# --- Módulo Compute ---
module "compute" {
  source                 = "../../modules/compute"
  project_name           = var.project_name
  ecs_security_group_id  = module.network.ecs_security_group_id
  private_subnet_ids     = module.network.private_subnet_ids
}

# --- Módulo Storage (EFS) ---
module "storage" {
  source                 = "../../modules/storage"
  project_name           = var.project_name
  creation_token         = "${var.project_name}-efs"
  vpc_id                 = module.network.vpc_id
  private_subnet_ids     = module.network.private_subnet_ids
  ecs_security_group_id  = module.network.ecs_security_group_id
}

# --- Módulo Database ---
module "database" {
  source                 = "../../modules/database"
  project_name           = var.project_name
  vpc_id                 = module.network.vpc_id
  private_subnet_ids     = module.network.private_subnet_ids
  ecs_security_group_id  = module.network.ecs_security_group_id
}

# --- Módulo App ---
module "app" {
  source                = "../../modules/app"
  project_name          = var.project_name
  region                = var.region
  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  alb_security_group_id = module.network.alb_security_group_id
  cluster_id            = module.compute.cluster_id
  efs_id                = module.storage.efs_id

  ssm_db_host_arn = module.database.ssm_db_host_arn
  ssm_db_user_arn = module.database.ssm_db_user_arn
  ssm_db_pass_arn = module.database.ssm_db_pass_arn
  ssm_db_name_arn = module.database.ssm_db_name_arn
}

# --- Outputs ---
output "website_url" {
  description = "URL do WordPress"
  value       = "http://${module.app.alb_dns_name}"
}

output "alb_dns_name" {
  description = "DNS do Load Balancer"
  value       = module.app.alb_dns_name
}
