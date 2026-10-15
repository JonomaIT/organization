provider "aws" {
  region = var.region

  # Every resource gets the same tags; the component only declares what is specific to it.
  # No commit tag: it would change on every apply and show every resource as modified.
  default_tags {
    tags = {
      "jonomait:env"        = var.environment
      "jonomait:app"        = "plataforma"
      "jonomait:repo"       = "organization"
      "jonomait:component"  = "bootstrap"
      "jonomait:managed-by" = "terraform"
    }
  }
}
