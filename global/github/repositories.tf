# The org standard, applied to every repo in var.repositories.

resource "github_repository" "repo" {
  for_each = var.repositories

  name         = each.key
  description  = each.value.description
  homepage_url = each.value.homepage
  visibility   = "public"
  is_template  = each.value.is_template
  topics       = sort(distinct(concat(["layer-${each.value.kind}"], each.value.topics)))

  # Squash only: one commit per PR on main, titled by the PR (Conventional Commits feed the
  # releases), so history stays linear and reverting a change is reverting one commit.
  allow_squash_merge          = true
  allow_merge_commit          = false
  allow_rebase_merge          = false
  squash_merge_commit_title   = "PR_TITLE"
  squash_merge_commit_message = "PR_BODY"
  allow_auto_merge            = true
  allow_update_branch         = true
  delete_branch_on_merge      = true

  # Docs live in the repo (README, ADRs) and the backlog in issues.
  has_issues      = true
  has_wiki        = false
  has_projects    = false
  has_discussions = false

  security_and_analysis {
    secret_scanning {
      status = "enabled"
    }
    secret_scanning_push_protection {
      status = "enabled"
    }
  }

  archive_on_destroy = true # removing a repo from the list archives it, never deletes it

  lifecycle {
    prevent_destroy = true
  }
}

resource "github_repository_vulnerability_alerts" "repo" {
  for_each = var.repositories

  repository = github_repository.repo[each.key].name
  enabled    = true
}

resource "github_repository_dependabot_security_updates" "repo" {
  for_each = var.repositories

  repository = github_repository.repo[each.key].name
  enabled    = true

  depends_on = [github_repository_vulnerability_alerts.repo]
}
