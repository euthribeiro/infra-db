locals {
  colunas_lambda_auth = {
    Clientes = ["Id", "Documento", "Email"]
    Usuarios = ["Id", "Email", "PerfilId", "Ativo"]
    Perfis   = ["Id", "Nome"]
  }

  lambda_auth_databases_habilitados = merge(
    var.lambda_auth_grants_production ? { production = local.database_production } : {},
    var.lambda_auth_grants_homologacao ? { homologacao = local.database_homologacao } : {}
  )

  lambda_auth_grants_colunas = merge([
    for ambiente, database in local.lambda_auth_databases_habilitados : {
      for tabela, colunas in local.colunas_lambda_auth :
      "${ambiente}.${tabela}" => {
        database = database
        tabela   = tabela
        colunas  = colunas
      }
    }
  ]...)
}

resource "postgresql_role" "lambda_auth" {
  name     = var.lambda_auth_database_username
  login    = true
  password = var.lambda_auth_database_password
}

resource "postgresql_grant" "lambda_auth_database_production" {
  count = var.lambda_auth_grants_production ? 1 : 0

  database    = local.database_production
  role        = postgresql_role.lambda_auth.name
  object_type = "database"
  privileges  = ["CONNECT"]
}

resource "postgresql_grant" "lambda_auth_schema_production" {
  count = var.lambda_auth_grants_production ? 1 : 0

  database    = local.database_production
  schema      = "public"
  role        = postgresql_role.lambda_auth.name
  object_type = "schema"
  privileges  = ["USAGE"]
}

resource "postgresql_grant" "lambda_auth_database_homologacao" {
  count = var.lambda_auth_grants_homologacao ? 1 : 0

  provider = postgresql.aplicacao

  database    = postgresql_database.homologacao.name
  role        = postgresql_role.lambda_auth.name
  object_type = "database"
  privileges  = ["CONNECT"]
}

resource "postgresql_grant" "lambda_auth_schema_homologacao" {
  count = var.lambda_auth_grants_homologacao ? 1 : 0

  database    = postgresql_database.homologacao.name
  schema      = "public"
  role        = postgresql_role.lambda_auth.name
  object_type = "schema"
  privileges  = ["USAGE"]
}

resource "postgresql_grant" "lambda_auth_colunas" {
  for_each = local.lambda_auth_grants_colunas

  database    = each.value.database
  schema      = "public"
  role        = postgresql_role.lambda_auth.name
  object_type = "column"
  objects     = [each.value.tabela]
  columns     = each.value.colunas
  privileges  = ["SELECT"]

  depends_on = [
    postgresql_grant.lambda_auth_schema_production,
    postgresql_grant.lambda_auth_schema_homologacao,
  ]
}
