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

variable "lambda_auth_grants_production" {
  description = "Concede ao role da Lambda CONNECT, USAGE e SELECT por coluna no database de produção. Só pode ser true depois que as migrations da API criarem as tabelas nesse database."
  type        = bool
  default     = false
}

variable "lambda_auth_grants_homologacao" {
  description = "Concede ao role da Lambda CONNECT, USAGE e SELECT por coluna no database de homologação. Só pode ser true depois que as migrations da API criarem as tabelas nesse database."
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

variable "billing_database_name" {
  description = "Database do Billing Service em produção. O de homologação recebe o sufixo _hml."
  type        = string
  default     = "wrench_billing"
}

variable "billing_database_username" {
  description = "Role de menor privilégio do Billing Service, dono dos seus databases."
  type        = string
  sensitive   = true
  default     = "wrench_billing"
}

variable "billing_database_password" {
  description = "Senha do role do Billing Service."
  type        = string
  sensitive   = true
}