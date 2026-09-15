resource "postgresql_role" "app" {
  name     = var.application_database_username
  login    = true
  password = var.application_database_password
}

resource "postgresql_grant" "database" {
  database    = local.db_name
  role        = postgresql_role.app.name
  object_type = "database"
  privileges  = ["CONNECT", "CREATE"]
}

resource "postgresql_grant" "schema" {
  database    = local.db_name
  schema      = "public"
  role        = postgresql_role.app.name
  object_type = "schema"
  privileges  = ["USAGE", "CREATE"]
}

resource "postgresql_grant" "tables" {
  database    = local.db_name
  schema      = "public"
  role        = postgresql_role.app.name
  object_type = "table"

  privileges = [
    "SELECT",
    "INSERT",
    "UPDATE",
    "DELETE",
    "TRUNCATE",
    "REFERENCES",
    "TRIGGER",
  ]
}

resource "postgresql_grant" "sequences" {
  database    = local.db_name
  schema      = "public"
  role        = postgresql_role.app.name
  object_type = "sequence"

  privileges = [
    "USAGE",
    "SELECT",
    "UPDATE",
  ]
}
