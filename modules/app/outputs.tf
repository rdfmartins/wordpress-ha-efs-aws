output "alb_dns_name" {
  description = "DNS público para acessar o WordPress"
  value       = aws_lb.this.dns_name
}
