variable "application_database_username" {
  description = "Role de menor privilégio da aplicação, dono das tabelas criadas pelas migrations."
  type        = string
  sensitive   = true
}

variable "application_database_password" {
  description = "Senha do role da aplicação."
  type        = string
  sensitive   = true
}

variable "rds_master_username" {
  description = "Usuário master do RDS, usado para criar os roles."
  type        = string
  sensitive   = true
}

variable "rds_master_password" {
  description = "Senha do usuário master do RDS."
  type        = string
  sensitive   = true
}

variable "lambda_auth_database_username" {
  description = "Role somente leitura da Lambda de autenticação."
  type        = string
  sensitive   = true
  default     = "wrench_lambda_auth"
}

variable "lambda_auth_database_password" {
  description = "Senha do role somente leitura da Lambda de autenticação."
  type        = string
  sensitive   = true
}

variable "lambda_auth_column_grants_enabled" {
  description = "Aplica o SELECT por coluna da Lambda de autenticação. Só pode ser true depois que as migrations da API criarem as tabelas."
  type        = bool
  default     = false
}

variable "tfc_organization" {
  description = "Organização no HCP Terraform."
  type        = string
  default     = "bgt3"
}

variable "rds_workspace" {
  description = "Workspace HCP do stack rds/, de onde vêm endpoint e nome do banco."
  type        = string
  default     = "wrench_auto_repair_rds"
}
