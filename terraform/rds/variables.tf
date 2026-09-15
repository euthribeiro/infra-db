variable "projectName" {
  description = "Nome do projeto, usado como prefixo dos recursos."
  type        = string
  default     = "wrench-auto-repair"
}

variable "region_default" {
  description = "Regiao AWS onde a instancia RDS e provisionada."
  type        = string
  default     = "us-east-1"
}

variable "tfc_organization" {
  description = "Organizacao no HCP Terraform."
  type        = string
  default     = "bgt3"
}

variable "infra_workspace" {
  description = "Workspace HCP da infraestrutura Kubernetes, de onde vem a VPC e as subnets publicas."
  type        = string
  default     = "wrench_auto_repair"
}

variable "rds_database_identifier" {
  description = "Identificador da instancia no RDS."
  type        = string
  default     = "db-wrench-auto-repair"
}

variable "rds_database_name" {
  description = "Nome do banco principal da aplicacao."
  type        = string
  default     = "wrench_auto_repair"
}

variable "rds_database_allocated_storage" {
  description = "Armazenamento alocado, em gigabytes."
  type        = number
  default     = 20

  validation {
    condition     = var.rds_database_allocated_storage >= 20
    error_message = "O tamanho mínimo de armazenamento é 20 Gigabytes"
  }
}

variable "rds_database_engine" {
  description = "Engine do banco de dados."
  type        = string
  default     = "postgres"
}

variable "rds_database_engine_version" {
  description = "Versao da engine do banco de dados."
  type        = string
  default     = "18"
}

variable "rds_database_instance_class" {
  description = "Classe da instancia RDS."
  type        = string
  default     = "db.t4g.micro"
}

variable "rds_database_username" {
  description = "Usuario master do RDS."
  type        = string
  sensitive   = true
}

variable "rds_database_password" {
  description = "Senha do usuario master do RDS."
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  description = "API Token do Cloudflare com permissao Zone.DNS:Edit."
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Zone ID do dominio no Cloudflare."
  type        = string
  sensitive   = true
}

variable "root_domain" {
  description = "Dominio raiz gerenciado no Cloudflare."
  type        = string
  default     = "bgt3.com.br"
}
