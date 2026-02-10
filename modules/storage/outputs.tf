output "efs_id" {
  description = "ID do Sistema de Arquivos EFS criado"
  value       = aws_efs_file_system.this.id
}

output "efs_dns_name" {
  description = "DNS do EFS para montagem nos containers"
  value       = aws_efs_file_system.this.dns_name
}

output "efs_security_group_id" {
  description = "ID do Security Group associado ao EFS"
  value       = aws_security_group.efs.id
}
