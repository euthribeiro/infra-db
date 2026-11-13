provider "postgresql" {
  host      = local.db_address
  port      = 5432
  database  = local.db_name
  username  = var.rds_master_username
  password  = var.rds_master_password
  sslmode   = "require"
  superuser = false
}

provider "postgresql" {
  alias = "aplicacao"

  host      = local.db_address
  port      = 5432
  database  = local.db_name
  username  = var.application_database_username
  password  = var.application_database_password
  sslmode   = "require"
  superuser = false
}

# Conecta como o role do Billing, dono dos databases dele. Só o dono consegue revogar o CONNECT que o
# PostgreSQL concede a PUBLIC (o master não é dono do database, então o REVOKE dele não tem efeito).
provider "postgresql" {
  alias = "billing"

  host      = local.db_address
  port      = 5432
  database  = local.billing_database_production
  username  = var.billing_database_username
  password  = var.billing_database_password
  sslmode   = "require"
  superuser = false
}