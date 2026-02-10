🗺️ ROADMAP DO PROJETO: HA WORDPRESS ON ECS
1. Fase 1: Fundação & Persistência (Atual)
    ◦ Setup da estrutura de diretórios e Git.
    ◦ Script de Bootstrap (Terraform State: S3 apenas, sem DynamoDB).
    ◦ Módulo Storage (EFS): Sistema de arquivos regional para compartilhar /var/www/html entre os containers.
2. Fase 2: Networking & Segurança
    ◦ Módulo Network: VPC, Subnets Públicas/Privadas (ou Data Source se já existir).
    ◦ Security Groups Base: Estratégia de Chaining (ALB -> ECS -> RDS/EFS).
3. Fase 3: Camada de Dados
    ◦ Módulo Database: RDS MySQL 5.7 Multi-AZ.
    ◦ SSM Parameter Store: Armazenamento seguro de credenciais (db_host, db_user, db_pass).
4. Fase 4: Compute Cluster
    ◦ Módulo Compute: ECS Cluster, Launch Template (EC2 T2.micro), Auto Scaling Group e Capacity Provider.
5. Fase 5: Application Delivery & Ingress
    ◦ Módulo App: ALB, Listeners, Target Groups (Health Checks 200, 301, 302).
    ◦ ECS Service & Task Definitions: Mapeamento de volumes e links de container.
