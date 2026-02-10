resource "aws_efs_file_system" "this" {
  creation_token   = var.creation_token
  performance_mode = "generalPurpose" # Padrão recomendado [18]
  throughput_mode  = "bursting"       # Escalabilidade automática sob demanda [18]
  encrypted        = true             # Best Practice de segurança [19]

  tags = {
    Name    = var.efs_name
    Project = var.project_name
  }
}

# Mount Targets: O elo entre o EFS e as Subnets da VPC
resource "aws_efs_mount_target" "this" {
  count           = length(var.private_subnet_ids)
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = var.private_subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}

# Security Group específico do EFS
# Permite tráfego NFS (2049) vindo APENAS do Security Group do ECS (Chaining) [4, 17]
resource "aws_security_group" "efs" {
  name        = "${var.project_name}-efs-sg"
  description = "Security Group for EFS allow NFS from ECS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "NFS from ECS Cluster"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [var.ecs_security_group_id] # Referência ao SG do Compute [4]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-efs-sg"
  }
}
