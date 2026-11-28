# The org standard, checked on the real catalog (env/management.tfvars) with a mocked GitHub: no token,
# no network. Every repo must come out squash-only, cleaned up on merge, scanned and protected.
mock_provider "github" {}

# Resources adopted with import blocks cannot be read by a mocked provider: these stand in.
override_resource {
  target = github_repository.repo
}
override_resource {
  target = github_repository_vulnerability_alerts.repo
}
override_resource {
  target = github_repository_dependabot_security_updates.repo
}
override_resource {
  target = github_repository_ruleset.main
}
override_resource {
  target = github_repository_ruleset.release_tags
}

run "every_repo_follows_the_standard" {
  command = plan

  assert {
    condition = alltrue([for r in github_repository.repo :
      r.allow_squash_merge && !r.allow_merge_commit && !r.allow_rebase_merge
    ])
    error_message = "Every repo must be squash-only."
  }

  assert {
    condition     = alltrue([for r in github_repository.repo : r.delete_branch_on_merge && r.allow_auto_merge])
    error_message = "Every repo must delete merged branches and allow auto-merge."
  }

  assert {
    condition = alltrue([for r in github_repository.repo :
      r.security_and_analysis[0].secret_scanning[0].status == "enabled" &&
      r.security_and_analysis[0].secret_scanning_push_protection[0].status == "enabled"
    ])
    error_message = "Every repo must have secret scanning and push protection."
  }

  assert {
    condition     = alltrue([for r in github_repository.repo : contains(r.topics, "layer-${var.repositories[r.name].kind}")])
    error_message = "Every repo must carry its layer-<kind> topic."
  }

  assert {
    condition     = length(github_repository_ruleset.main) == length([for r in var.repositories : r if !r.archived])
    error_message = "Every active repo must have a main ruleset."
  }

  assert {
    condition = alltrue([for name, r in var.repositories :
      github_repository.repo[name].archived == r.archived && (r.archived == !contains(keys(github_repository_ruleset.main), name))
    ])
    error_message = "Archived repos must be archived on GitHub and have no main ruleset; active ones keep theirs."
  }

  assert {
    condition = alltrue([for r in github_repository_ruleset.main :
      r.rules[0].pull_request[0].allowed_merge_methods == tolist(["squash"])
    ])
    error_message = "main must only accept squash merges."
  }

  assert {
    condition     = github_actions_organization_workflow_permissions.main.default_workflow_permissions == "read"
    error_message = "Workflows must get a read-only GITHUB_TOKEN by default."
  }
}

run "a_repo_without_checks_is_refused" {
  command = plan

  variables {
    repositories = {
      unguarded = { description = "x", kind = "app", checks = [] }
    }
  }

  expect_failures = [var.repositories]
}

run "an_unknown_kind_is_refused" {
  command = plan

  variables {
    repositories = {
      odd = { description = "x", kind = "service", checks = ["ci"] }
    }
  }

  expect_failures = [var.repositories]
}

run "dependabot_bypass_only_where_main_needs_a_review" {
  command = plan

  variables {
    dependabot_app_id = 123456
  }

  assert {
    condition = alltrue([for name, r in github_repository_ruleset.main :
      length(r.bypass_actors) == (var.repositories[name].approvals > 0 ? 2 : 0)
    ])
    error_message = "Only repos whose main needs approvals may let org admins and the Dependabot app skip the review."
  }

  assert {
    condition = alltrue(flatten([for r in github_repository_ruleset.main : [for b in r.bypass_actors :
      b.bypass_mode == "pull_request" && (
        (b.actor_type == "Integration" && b.actor_id == 123456) ||
        (b.actor_type == "OrganizationAdmin" && b.actor_id == 1)
      )
    ]]))
    error_message = "The bypass must be org admins or the Dependabot app, through a pull request only."
  }
}
