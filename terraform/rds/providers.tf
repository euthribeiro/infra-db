provider "aws" {
  region = var.region_default
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
