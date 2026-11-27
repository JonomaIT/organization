# main: nobody pushes to it directly, deletes it or rewrites it; everything lands through a PR whose
# required checks passed on the latest main (strict), squashed.
resource "github_repository_ruleset" "main" {
  for_each = var.repositories

  name        = "main"
  repository  = github_repository.repo[each.key].name
  target      = "branch"
  enforcement = "active"

  # Where main needs a review, two actors may skip it, and only through a PR (never a direct push):
  #   org admins            the org has a single maintainer, who cannot approve their own PR
  #   jonomait-dependabot   Dependabot patch and minor updates (pipelines dependabot-auto-merge)
  dynamic "bypass_actors" {
    for_each = each.value.approvals > 0 ? [1] : []
    content {
      actor_id    = 1 # the fixed id GitHub uses for the OrganizationAdmin role
      actor_type  = "OrganizationAdmin"
      bypass_mode = "pull_request"
    }
  }

  dynamic "bypass_actors" {
    for_each = var.dependabot_app_id != null && each.value.approvals > 0 ? [var.dependabot_app_id] : []
    content {
      actor_id    = bypass_actors.value
      actor_type  = "Integration"
      bypass_mode = "pull_request"
    }
  }

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  rules {
    deletion         = true
    non_fast_forward = true

    pull_request {
      allowed_merge_methods             = ["squash"]
      required_approving_review_count   = each.value.approvals
      require_code_owner_review         = each.value.code_owner_review
      dismiss_stale_reviews_on_push     = true
      required_review_thread_resolution = true
    }

    required_status_checks {
      strict_required_status_checks_policy = true

      dynamic "required_check" {
        for_each = toset(each.value.checks)
        content {
          context = required_check.value
        }
      }
    }
  }
}

# Release tags are immutable: a published version never moves and never disappears, so a ref pinned
# by a consumer always means the same code. v* for repo-wide tags, */v* for one version per module.
resource "github_repository_ruleset" "release_tags" {
  for_each = { for name, r in var.repositories : name => r if r.release_tags }

  name        = "version tags"
  repository  = github_repository.repo[each.key].name
  target      = "tag"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/tags/v*", "refs/tags/*/v*"]
      exclude = []
    }
  }

  rules {
    deletion         = true
    non_fast_forward = true
    update           = true
  }
}
