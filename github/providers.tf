# Credentials come from the environment, never from the code: GITHUB_TOKEN (an org owner's token,
# e.g. `gh auth token`, for the runs by hand) or GITHUB_APP_ID + GITHUB_APP_INSTALLATION_ID +
# GITHUB_APP_PEM_FILE (an app with Administration read/write, for a pipeline later).
provider "github" {
  owner = var.github_org
}
