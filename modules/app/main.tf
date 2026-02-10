# --- 1. Load Balancer (ALB) ---
resource "aws_lb" "this" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  tags = { Name = "${var.project_name}-alb" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress.arn
  }
}

# --- 2. Target Group (Com Health Check 301/302) ---
resource "aws_lb_target_group" "wordpress" {
  name        = "${var.project_name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance" # Necessário para Bridge Network mode

  health_check {
    path                = "/"
    matcher             = "200,301,302" # CRÍTICO: Redirecionamentos do WP
    interval            = 60
    timeout             = 30
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }
}

# --- 3. ECS Task Definition ---
resource "aws_ecs_task_definition" "wordpress" {
  family             = "${var.project_name}-task"
  network_mode       = "bridge" # Permite Dynamic Port Mapping
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  
  # Definição do Volume EFS (Persistência)
  volume {
    name = "efs-html"
    efs_volume_configuration {
      file_system_id = var.efs_id
      root_directory = "/" 
    }
  }

  container_definitions = jsonencode([
    {
      name      = "wordpress"
      image     = "wordpress:latest"
      cpu       = 512
      memory    = 512
      essential = true
      
      # Mapeamento de Portas Dinâmico
      portMappings = [
        {
          containerPort = 80
          hostPort      = 0 # Deixe o ECS escolher a porta no Host
          protocol      = "tcp"
        }
      ]

      # Montagem do Volume EFS
      mountPoints = [
        {
          sourceVolume  = "efs-html"
          containerPath = "/var/www/html" # Onde o WP mora
          readOnly      = false
        }
      ]

      # Injeção de Segredos via SSM (Segurança)
      secrets = [
        { name = "WORDPRESS_DB_HOST",      valueFrom = var.ssm_db_host_arn },
        { name = "WORDPRESS_DB_USER",      valueFrom = var.ssm_db_user_arn },
        { name = "WORDPRESS_DB_PASSWORD",  valueFrom = var.ssm_db_pass_arn },
        { name = "WORDPRESS_DB_NAME",      valueFrom = var.ssm_db_name_arn }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project_name}"
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "wp"
          "awslogs-create-group"  = "true"
        }
      }
    }
  ])
}

# --- 4. IAM Role para Execução da Task (Logs + Pull) ---
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-task-exec-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

# Permissão para puxar imagens e logs
resource "aws_iam_role_policy_attachment" "ecs_task_exec_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Permissão EXTRA para ler SSM Parameter Store
resource "aws_iam_role_policy" "ssm_read" {
  name = "ssm-read"
  role = aws_iam_role.ecs_task_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["ssm:GetParameters", "kms:Decrypt"]
      Resource = "*" # Em prod, restrinja aos ARNs específicos
    }]
  })
}

# --- 5. ECS Service ---
resource "aws_ecs_service" "main" {
  name            = "${var.project_name}-service"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.wordpress.arn
  desired_count   = 2 # Alta Disponibilidade (mínimo 2)
  launch_type     = "EC2"

  # Conexão com ALB
  load_balancer {
    target_group_arn = aws_lb_target_group.wordpress.arn
    container_name   = "wordpress"
    container_port   = 80
  }

  # Estratégia de Deploy
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  # Placement Strategy: Espalhar entre AZs para HA
  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }
}
