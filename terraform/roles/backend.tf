terraform {
  cloud {
    organization = "bgt3"

    workspaces {
      name = "wrench_auto_repair_postgres"
    }
  }
}
