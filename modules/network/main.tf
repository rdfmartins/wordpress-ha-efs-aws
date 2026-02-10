# --- VPC & Internet Gateway ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

# --- Data Source para obter AZs disponíveis ---
data "aws_availability_zones" "available" {
  state = "available"
}

# --- Subnets Públicas (Para o ALB) ---
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true # Necessário para o ALB/NAT

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
    Tier = "Public"
  }
}

# --- Subnets Privadas (Para ECS, RDS e EFS) ---
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
    Tier = "Private"
  }
}

# --- Roteamento ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Roteamento das Subnets de Aplicação (Ex-Privadas) ---
# Em PROD: Usaríamos NAT Gateway ($$$) e Subnets realmente privadas.
# Em DEV: Usamos rota para o IGW para economizar custos. As instâncias precisarão de Public IP.

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id # Rota direta para internet (Custo Zero)
  }

  tags = { Name = "${var.project_name}-private-rt" }
}

# Associação das Subnets
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# --- SECURITY GROUPS (A Base do Chaining) ---

# 1. ALB Security Group (Borda)
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP/HTTPS inbound"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from World"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. ECS Security Group (Aplicação)
resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-ecs-sg"
  description = "Allow traffic from ALB only"
  vpc_id      = aws_vpc.main.id

  # AQUI ESTÁ O CHAINING: A origem é o SG do ALB
  ingress {
    description     = "HTTP from ALB"
    from_port       = 0   # Porta 0 permite mapeamento dinâmico de portas do ECS
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
