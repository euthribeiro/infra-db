output "application_database_username" {
  description = "Role de menor privilégio da aplicação."
  value       = postgresql_role.app.name
  sensitive   = true
}

output "lambda_auth_database_username" {
  description = "Role somente leitura da Lambda de autenticação."
  value       = postgresql_role.lambda_auth.name
  sensitive   = true
}

output "database_production" {
  description = "Database da aplicação e da Lambda no ambiente de produção."
  value       = local.database_production
}

output "database_homologacao" {
  description = "Database da aplicação e da Lambda no ambiente de homologação, na mesma instância RDS."
  value       = postgresql_database.homologacao.name
}

output "lambda_auth_grants" {
  description = "Ambientes em que os grants por coluna da Lambda de autenticação estão aplicados."
  value       = keys(local.lambda_auth_databases_habilitados)
}
