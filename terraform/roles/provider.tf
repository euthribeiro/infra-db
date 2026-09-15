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
