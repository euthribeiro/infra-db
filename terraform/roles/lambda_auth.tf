locals {
  colunas_lambda_auth = {
    Clientes = ["Id", "Documento", "Email"]
    Usuarios = ["Id", "Email", "PerfilId", "Ativo"]
    Perfis   = ["Id", "Nome"]
  }
}

resource "postgresql_role" "lambda_auth" {
  name     = var.lambda_auth_database_username
  login    = true
  password = var.lambda_auth_database_password
}

resource "postgresql_grant" "lambda_auth_database" {
  database    = local.db_name
  role        = postgresql_role.lambda_auth.name
  object_type = "database"
  privileges  = ["CONNECT"]
}

resource "postgresql_grant" "lambda_auth_schema" {
  database    = local.db_name
  schema      = "public"
  role        = postgresql_role.lambda_auth.name
  object_type = "schema"
  privileges  = ["USAGE"]
}

resource "postgresql_grant" "lambda_auth_colunas" {
  for_each = var.lambda_auth_column_grants_enabled ? local.colunas_lambda_auth : {}

  provider = postgresql.aplicacao

  database    = local.db_name
  schema      = "public"
  role        = postgresql_role.lambda_auth.name
  object_type = "column"
  objects     = [each.key]
  columns     = each.value
  privileges  = ["SELECT"]

  depends_on = [postgresql_grant.lambda_auth_schema]
}
