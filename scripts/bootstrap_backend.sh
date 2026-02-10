#!/bin/bash
# Usage: ./bootstrap_backend.sh <region> <project-name>
# Ex: ./bootstrap_backend.sh us-east-1 ha-wordpress-lab
# Nota: Usa apenas S3 (sem DynamoDB) - ideal para uso solo/teste

REGION=$1
PROJECT=$2
BUCKET_NAME="${PROJECT}-tf-state-${RANDOM}"

echo ">>> Iniciando Bootstrap do Backend Terraform (S3 apenas)..."

# Criar Bucket S3
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "Bucket $BUCKET_NAME já existe."
else
  echo "Criando Bucket $BUCKET_NAME..."
  aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
  # Habilitar Versionamento (Best Practice para Recovery)
  aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled
fi

echo ">>> Bootstrap Concluído."
echo "Bucket: $BUCKET_NAME"
echo ""
echo "Configure seu backend.tf com:"
echo "  bucket = \"$BUCKET_NAME\""
echo "  region = \"$REGION\""
echo ""
echo "Atenção: Sem DynamoDB não há state locking. Evite rodar terraform apply em paralelo."
