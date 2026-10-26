# ==============================================================================
# DIGITALFIX - OUTPUTS
# ==============================================================================

output "ec2_public_ip" {
  description = "IP pública elástica de la EC2 (no cambia si reinicias la instancia)"
  value       = aws_eip.ec2.public_ip
}

output "ec2_public_dns" {
  description = "DNS público de la Elastic IP"
  value       = aws_eip.ec2.public_dns
}

output "frontend_url" {
  description = "URL del frontend Angular SSR"
  value       = "http://${aws_eip.ec2.public_ip}:${var.frontend_port}"
}

output "bff_url" {
  description = "URL del BFF/API Gateway"
  value       = "http://${aws_eip.ec2.public_ip}:${var.bff_port}"
}

output "rabbitmq_management_url" {
  description = "URL de la consola de administración de RabbitMQ"
  value       = "http://${aws_eip.ec2.public_ip}:15672"
}

output "ssh_command" {
  description = "Comando SSH para conectarte a la EC2"
  value       = "ssh -i ~/.ssh/digitalfix-server.pem ec2-user@${aws_eip.ec2.public_ip}"
}

output "bootstrap_log_command" {
  description = "Comando para ver el log del bootstrap en la EC2"
  value       = "ssh -i ~/.ssh/digitalfix-server.pem ec2-user@${aws_eip.ec2.public_ip} 'sudo tail -f /var/log/digitalfix-bootstrap.log'"
}

output "ec2_instance_id" {
  description = "ID de la instancia EC2"
  value       = aws_instance.app.id
}

output "security_group_id" {
  description = "ID del Security Group de la EC2"
  value       = aws_security_group.app.id
}
