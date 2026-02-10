output "db_endpoint" {
  value = aws_db_instance.this.endpoint
}

output "ssm_db_host_arn" { value = aws_ssm_parameter.db_host.arn }
output "ssm_db_user_arn" { value = aws_ssm_parameter.db_user.arn }
output "ssm_db_pass_arn" { value = aws_ssm_parameter.db_pass.arn }
output "ssm_db_name_arn" { value = aws_ssm_parameter.db_name.arn }
