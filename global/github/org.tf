# Actions, for the whole org: which actions may run, and what a workflow's GITHUB_TOKEN can do by
# default (read only; a workflow asks for more in its own permissions block).

resource "github_actions_organization_permissions" "main" {
  enabled_repositories = "all"
  allowed_actions      = "selected"

  allowed_actions_config {
    github_owned_allowed = true # actions/*
    verified_allowed     = true # Marketplace verified creators (aws-actions, hashicorp...)
    patterns_allowed     = var.allowed_action_patterns
  }
}

resource "github_actions_organization_workflow_permissions" "main" {
  organization_slug                = var.github_org
  default_workflow_permissions     = "read"
  can_approve_pull_request_reviews = true # release PRs (release-please)
}
