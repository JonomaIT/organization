# Credentials come from the environment, never from the code: GITHUB_TOKEN, an installation token of
# the jonomait-settings[-plan] app in the pipeline (.github/workflows/github-settings.yml), or an
# org owner's `gh auth token` for a run by hand.
provider "github" {
  owner = var.github_org
}
