terraform {
  required_version = ">= 1.10" # native S3 state locking (use_lockfile)

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.13"
    }
  }
}
