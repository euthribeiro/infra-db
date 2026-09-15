data "terraform_remote_state" "infra" {
  backend = "remote"

  config = {
    organization = var.tfc_organization
    workspaces = {
      name = var.infra_workspace
    }
  }
}

locals {
  vpc_id            = data.terraform_remote_state.infra.outputs.vpc_id
  public_subnet_ids = data.terraform_remote_state.infra.outputs.public_subnet_ids
}
