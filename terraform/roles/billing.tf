# Billing Service (Fase 4): um database exclusivo por ambiente, na mesma instância RDS,
# com um role de menor privilégio próprio. Nenhum outro serviço deve acessar esses databases.
#
# O role é dono dos databases. Como a aplicação é Code First (EF Migrations), as tabelas são criadas
# pelo próprio role, dono do schema public (pg_database_owner), então não há grants de tabela nem
# default privileges, como no database de homologação da API.
locals {
  billing_database_production  = var.billing_database_name
  billing_database_homologacao = "${var.billing_database_name}_hml"

  billing_databases = {
    production  = local.billing_database_production
    homologacao = local.billing_database_homologacao
  }
}

resource "postgresql_role" "billing" {
  name             = var.billing_database_username
  login            = true
  password         = var.billing_database_password
  superuser        = false
  create_database  = false
  create_role      = false
  connection_limit = 20
}

resource "postgresql_database" "billing" {
  for_each = local.billing_databases

  name              = each.value
  owner             = postgresql_role.billing.name
  allow_connections = true
  connection_limit  = -1
}

# O PostgreSQL concede CONNECT e TEMPORARY a PUBLIC por padrão. Revogá-los impede que os roles dos outros
# serviços (API, Lambda de autenticação, Execução) sequer conectem nos databases do Billing.
#
# Precisa do provider "billing" (conectado como o dono): o REVOKE do master não tem efeito, porque só o
# dono do database revoga o que ele mesmo concedeu. Verificado em Postgres real: com o provider padrão a ACL
# continuava `=Tc/...` e o plano nunca convergia.
resource "postgresql_grant" "billing_revoga_public" {
  for_each = local.billing_databases
  provider = postgresql.billing

  database    = postgresql_database.billing[each.key].name
  role        = "public"
  object_type = "database"
  privileges  = []
}

# Sem o PUBLIC, o master do RDS também deixaria de conectar nesses databases (verificado em Postgres real).
# O CONNECT explícito mantém o acesso operacional (diagnóstico, dump) sem reabrir para os outros serviços.
resource "postgresql_grant" "billing_master_conecta" {
  for_each = local.billing_databases
  provider = postgresql.billing

  database    = postgresql_database.billing[each.key].name
  role        = var.rds_master_username
  object_type = "database"
  privileges  = ["CONNECT"]

  depends_on = [postgresql_grant.billing_revoga_public]
}