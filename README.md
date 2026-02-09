# wordpress-ha-efs-aws
Arquitetura WordPress escalável na AWS usando EFS para persistência compartilhada entre contêineres Docker. Resolve inconsistências de dados em cenários de Auto Scaling por meio de Infraestrutura como Código (Terraform).

Utilizaremos de inicio:
O script bootstrap_backend.sh esse script automatiza a criação do "ovo e a galinha" (S3 e DynamoDB) para que o Terraform possa guardar seu estado remotamente.