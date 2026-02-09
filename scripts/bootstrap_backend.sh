#!/bin/bash
# Usage: ./bootstrap_backend.sh <region> <project-name>
# Ex: ./bootstrap_backend.sh us-east-1 ha-wordpress-lab

REGION=$1
PROJECT=$2
BUCKET_NAME="${PROJECT}-tf-state-${RANDOM}"
DYNAMO_TABLE="${PROJECT}-tf-lock"

echo ">>> Iniciando Bootstrap do Backend Terraform..."

# Criar Bucket S3
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "Bucket $BUCKET_NAME já existe."
else
  echo "Criando Bucket $BUCKET_NAME..."
  aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
  # Habilitar Versionamento (Best Practice para Recovery)
  aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled
fi

# Criar Tabela DynamoDB para State Locking
if aws dynamodb describe-table --table-name "$DYNAMO_TABLE" --region "$REGION" 2>/dev/null; then
  echo "Tabela DynamoDB $DYNAMO_TABLE já existe."
else
  echo "Criando Tabela DynamoDB $DYNAMO_TABLE..."
  aws dynamodb create-table \
    --table-name "$DYNAMO_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region "$REGION"
fi

echo ">>> Bootstrap Concluído."
echo "Bucket: $BUCKET_NAME"
echo "DynamoDB Table: $DYNAMO_TABLE"
echo "Configure seu backend.tf com estes valores."