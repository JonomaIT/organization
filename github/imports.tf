# Adoption of what already exists (27/11/2026): the repos and their hand-made rulesets are imported
# instead of created. Import blocks are a no-op once the resources are in the state; delete this
# file after the first apply.
locals {
  existing_main_rulesets = {
    "organization"       = 25214520
    "infrastructure"     = 25214521
    "terraform-modules"  = 25214519
    "pipelines"          = 25214523
    "template-web-react" = 25854588
    "svc-sales-api"      = 25518619
    "svc-sales-worker"   = 25518620
    "web-sales"          = 25519903
  }
  existing_tag_rulesets = {
    "terraform-modules" = 25214532
    "pipelines"         = 25214531
  }
}

import {
  for_each = var.repositories
  to       = github_repository.repo[each.key]
  id       = each.key
}

import {
  for_each = var.repositories
  to       = github_repository_vulnerability_alerts.repo[each.key]
  id       = each.key
}

import {
  for_each = var.repositories
  to       = github_repository_dependabot_security_updates.repo[each.key]
  id       = each.key
}

import {
  for_each = local.existing_main_rulesets
  to       = github_repository_ruleset.main[each.key]
  id       = "${each.key}:${each.value}"
}

import {
  for_each = local.existing_tag_rulesets
  to       = github_repository_ruleset.release_tags[each.key]
  id       = "${each.key}:${each.value}"
}
