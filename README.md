# WordPress HA on AWS ECS + EFS

Arquitetura de WordPress em **Alta Disponibilidade** na AWS, usando ECS, EFS e RDS. Infraestrutura como Código com Terraform.

---

## O que foi construído (e por quê)

### O problema

WordPress roda em containers Docker e precisa de **storage persistente** para uploads, temas e plugins (`/var/www/html`). Em ambientes com múltiplas instâncias (Auto Scaling), cada container tem seu próprio sistema de arquivos. Sem compartilhamento, você teria:

- Uploads que aparecem em uma instância e não em outra  
- Plugins instalados em um container, ausentes nos demais  
- Inconsistência de dados e experiência ruim para o usuário  

### A solução

Esta arquitetura usa **Amazon EFS** (Elastic File System) como sistema de arquivos compartilhado entre todos os containers. O `/var/www/html` do WordPress fica no EFS, acessível por todas as tasks ECS, garantindo consistência mesmo com escalonamento horizontal.

---

## Arquitetura

```
                    ┌─────────────────────────────────────┐
                    │           Internet (HTTP)           │
                    └─────────────────┬───────────────────┘
                                      │
                    ┌─────────────────▼───────────────────┐
                    │   Application Load Balancer (ALB)   │
                    │   Subnets Públicas (NAT Gateway)    │
                    └─────────────────┬───────────────────┘
                                      │ Security Group Chaining
                    ┌─────────────────▼───────────────────┐
                    │         ECS Cluster (EC2)           │
                    │   WordPress Containers (x2)         │
                    │   Subnets Privadas                  │
                    └─────┬───────────────────┬───────────┘
                          │                   │
            ┌─────────────▼───────┐   ┌───────▼──────────────┐
            │     Amazon EFS      │   │   RDS MySQL 8.0      │
            │  /var/www/html      │   │   Multi-AZ           │
            │  (uploads, temas)   │   │   SSM Parameters     │
            └─────────────────────┘   └──────────────────────┘
```

### Princípios aplicados

| Conceito | Implementação |
|----------|---------------|
| **Persistência compartilhada** | EFS montado em `/var/www/html` de todos os containers |
| **Alta disponibilidade** | RDS Multi-AZ, ECS com 2+ tasks, spread entre AZs |
| **Segurança em camadas** | Chaining de SGs, segredos fora do código |
| **Otimização de Custos (Dev)** | Instâncias com IP Público (sem NAT Gateway) para economizar ~$32/mês |
| **Infraestrutura como Código** | Terraform modular e versionado |

---

## Decisões de Arquitetura & FinOps (Importante)

Para este projeto, foi tomada uma decisão consciente de design focada em **FinOps** (Gestão Financeira em Nuvem):

### NAT Gateway vs. Roteamento Direto via IGW
Em uma arquitetura Enterprise de Produção, as instâncias ECS ficariam em subnets 100% privadas, acessando a internet através de um **NAT Gateway**. No entanto, o NAT Gateway possui um custo fixo de aproximadamente **US$ 32,00/mês**.

**Manobra aplicada para o ambiente de Lab/Dev:**
- **Economia:** Removemos o NAT Gateway, reduzindo a fatura mensal em cerca de 45%.
- **Conectividade:** Configuramos as subnets de aplicação com rota direta para o **Internet Gateway (IGW)** e habilitamos IPs públicos nas instâncias EC2. Isso permite que o ECS realize o `docker pull` das imagens sem custos adicionais.
- **Segurança Mantida:** Mesmo com IPs públicos, a segurança **não foi comprometida**. Utilizamos o conceito de **Security Group Chaining**, onde as instâncias ECS aceitam tráfego estritamente vindo do Load Balancer (ALB). Qualquer tentativa de acesso direto da internet é descartada na camada de firewall da AWS.

Esta abordagem demonstra a capacidade de arquitetar soluções que equilibram **Alta Disponibilidade**, **Segurança** e **Eficiência de Custos**.

---

## Stack tecnológica

- **Terraform** – IaC (módulos reutilizáveis)  
- **Amazon ECS** – Orquestração de containers  
- **Amazon EFS** – Storage compartilhado  
- **Amazon RDS** – MySQL 8.0 Multi-AZ  
- **Application Load Balancer** – Tráfego HTTP e health checks  
- **SSM Parameter Store** – Credenciais do banco  
- **VPC** – Subnets públicas/privadas, NAT Gateway  

---

## Estrutura do projeto

```
.
├── environments/dev/          # Ambiente de desenvolvimento
│   ├── main.tf               # Orquestração dos módulos
│   └── backend.tf            # State remoto (S3)
├── modules/
│   ├── network/              # VPC, Subnets, Security Groups
│   ├── compute/              # ECS Cluster, ASG, Capacity Provider
│   ├── storage/              # EFS + Mount Targets
│   ├── database/             # RDS MySQL + SSM Parameters
│   └── app/                  # ALB, Task Definition, ECS Service
├── scripts/
│   └── bootstrap_backend.sh  # Cria bucket S3 para o state
└── contexto.md               # Roadmap e fases do projeto
```

---

## Pré-requisitos

- [Terraform](https://www.terraform.io/downloads) >= 1.0  
- [AWS CLI](https://aws.amazon.com/cli/) configurado com credenciais  
- Conta AWS (ambiente de teste – custos estimados ~US$ 60–70/mês)

---

## Como usar

### 1. Bootstrap do backend (primeira vez)

```bash
./scripts/bootstrap_backend.sh us-east-1 ha-wordpress
```

O script cria o bucket S3 para o state do Terraform. Copie o nome do bucket exibido no final.

> **DynamoDB em produção:** Este projeto usa apenas S3 para o state (ideal para uso solo/teste). Em **produção**, recomenda-se adicionar DynamoDB para **state locking**. Suas vantagens:
> - **Evita conflitos** – Impede que dois `terraform apply` rodem simultaneamente  
> - **Protege o state** – Reduz risco de corrupção em execuções paralelas  
> - **Essencial em times** – Quando várias pessoas aplicam mudanças ou em pipelines CI/CD  
> - **Best practice HashiCorp** – Praticamente obrigatório em ambientes colaborativos

### 2. Configurar e aplicar

```bash
cd environments/dev

# Edite backend.tf e substitua BUCKET_NAME pelo retorno do bootstrap
# Ou use: terraform init -backend-config="bucket=NOME_DO_BUCKET"

terraform init
terraform plan
terraform apply
```

### 3. Acessar o WordPress

Após o apply, o output `website_url` mostra a URL do WordPress (ex.: `http://xxx.us-east-1.elb.amazonaws.com`).

---

## Custos (estimativa)

| Recurso | Custo aproximado/mês |
|---------|----------------------|
| EC2 (2x t3.micro) | ~US$ 18 |
| RDS Multi-AZ | ~US$ 30 |
| ALB | ~US$ 16 |
| EFS | ~US$ 1–5 |
| **Total** | **~US$ 65–70** |

**Dica:** Use `terraform destroy` ao final dos testes para evitar cobranças contínuas.

---

## Próximos passos

Para tornar a arquitetura ainda mais robusta, as seguintes evoluções estão planejadas:

- **CDN (CloudFront)** – Colocar o CloudFront na frente do ALB para entregar assets estáticos (imagens, CSS, JS) na borda, reduzindo latência e carga no ECS.
- **Cache (ElastiCache ou CloudFront)** – Implementar camada de cache: ElastiCache Redis para sessões/objetos do WordPress, ou cache no próprio CloudFront para páginas e assets.

---

## Habilidades demonstradas

Este projeto evidencia:

- **IaC com Terraform** – Módulos reutilizáveis, boas práticas
- **Arquitetura cloud** – HA, multi-AZ, camadas de rede
- **Segurança** – Chaining de SGs, segredos fora do código
- **Automação** – Script de bootstrap, deploy reproduzível
- **Pensamento em produção** – EFS para storage compartilhado, health checks adequados ao WordPress

---

Rodolfo Martins | AWS Cloud Engineer
- São Paulo, Brasil.