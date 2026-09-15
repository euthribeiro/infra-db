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

output "lambda_auth_column_grants_enabled" {
  description = "Indica se os grants por coluna da Lambda de autenticação foram aplicados."
  value       = var.lambda_auth_column_grants_enabled
}
