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

# O PostgreSQL concede CONNECT a PUBLIC por padrão. Revogá-lo impede que os roles dos outros serviços
# (API, Lambda de autenticação, Execução) sequer conectem nos databases do Billing. O dono continua
# conectando. Conferir no primeiro plan/apply se o master do RDS mantém o acesso necessário.
resource "postgresql_grant" "billing_revoga_public" {
  for_each = local.billing_databases

  database    = postgresql_database.billing[each.key].name
  role        = "public"
  object_type = "database"
  privileges  = []
}