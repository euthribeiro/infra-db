data "terraform_remote_state" "rds" {
  backend = "remote"

  config = {
    organization = var.tfc_organization
    workspaces = {
      name = var.rds_workspace
    }
  }
}

locals {
  db_address = data.terraform_remote_state.rds.outputs.database_address
  db_name    = data.terraform_remote_state.rds.outputs.database_name

  database_production  = local.db_name
  database_homologacao = "${local.db_name}_hml"
}
