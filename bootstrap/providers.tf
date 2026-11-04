provider "aws" {
  region = var.region

  # Every resource gets the same tags; the component only declares what is specific to it.
  # No commit tag: it would change on every apply and show every resource as modified.
  default_tags {
    tags = {
      "${var.prefix}:env"        = var.environment
      "${var.prefix}:app"        = "plataforma"
      "${var.prefix}:repo"       = "organization"
      "${var.prefix}:component"  = "bootstrap"
      "${var.prefix}:managed-by" = "terraform"
    }
  }
}
