output "database_address" {
  description = "Endpoint direto do RDS. Consumido pelo stack roles/ e pelo deploy da aplicacao."
  value       = aws_db_instance.wrench_db.address
}

output "database_name" {
  description = "Nome do banco principal da aplicacao."
  value       = var.rds_database_name
}

output "database_hostname" {
  description = "CNAME publico do banco (prod-db.<root_domain>), usado pela aplicacao."
  value       = "prod-db.${var.root_domain}"
  depends_on  = [cloudflare_dns_record.db]
}

output "database_security_group_id" {
  description = "Security group que libera a porta 5432 da instancia."
  value       = aws_security_group.allow_postgres_traffic.id
}
