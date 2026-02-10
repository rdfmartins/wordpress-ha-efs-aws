# --- Gerador de Senha Segura ---
resource "random_password" "db_pass" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# --- Subnet Group (Onde o banco vive) ---
resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# --- Security Group do Banco (Chaining) ---
resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "Allow MySQL access from ECS only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from ECS"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.ecs_security_group_id] # Apenas o SG do ECS entra aqui [4]
  }

  tags = { Name = "${var.project_name}-db-sg" }
}

# --- Instância RDS ---
resource "aws_db_instance" "this" {
  identifier        = "${var.project_name}-mysql"
  engine            = "mysql"
  engine_version    = "8.0"       # Versão atualizada para suporte moderno
  instance_class    = "db.t3.micro" # Free Tier friendly, mas T3 é superior à T2
  
  db_name           = var.db_name
  username          = var.db_user
  password          = random_password.db_pass.result
  
  multi_az               = true   # Requisito de Alta Disponibilidade
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  
  allocated_storage     = 20
  max_allocated_storage = 100     # Autoscaling de storage
  storage_type          = "gp2"
  skip_final_snapshot   = true    # Cuidado: Em prod real, isso deve ser false

  tags = { Name = "${var.project_name}-rds" }
}

# --- SSM Parameter Store (O Cofre) ---
# Guardamos os dados para o ECS ler depois [1]

resource "aws_ssm_parameter" "db_host" {
  name  = "/${var.project_name}/database/host"
  type  = "String"
  value = aws_db_instance.this.address
}

resource "aws_ssm_parameter" "db_user" {
  name  = "/${var.project_name}/database/user"
  type  = "String"
  value = var.db_user
}

resource "aws_ssm_parameter" "db_pass" {
  name  = "/${var.project_name}/database/password"
  type  = "SecureString" # Criptografado com KMS default
  value = random_password.db_pass.result
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/${var.project_name}/database/name"
  type  = "String"
  value = var.db_name
}