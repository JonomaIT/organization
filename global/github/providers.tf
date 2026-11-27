# Credentials come from the environment, never from the code: GITHUB_TOKEN, an installation token of
# the jonomait-settings[-plan] app in the Deploy pipeline (pipelines terraform-deploy, github-app), or an
# org owner's `gh auth token` for a run by hand.
provider "github" {
  owner = var.github_org
}
