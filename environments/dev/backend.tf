# Backend S3 (sem DynamoDB)
# 1. Rode: ./scripts/bootstrap_backend.sh us-east-1 ha-wordpress
# 2. Init: terraform init -backend-config="bucket=NOME_DO_BUCKET"
#    Ou edite a linha bucket abaixo com o nome retornado pelo script

terraform {
  backend "s3" {
    bucket  = "BUCKET_NAME" # Substituir pelo output do bootstrap
    key     = "dev/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
