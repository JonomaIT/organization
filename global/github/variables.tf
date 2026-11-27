variable "github_org" {
  type        = string
  description = "GitHub organization these settings apply to (e.g. JonomaIT)"
}

variable "allowed_action_patterns" {
  type        = list(string)
  description = "Third-party actions allowed besides GitHub's own (actions/*) and Marketplace verified creators, as owner/repo@ref patterns. The org's own repos are always allowed."
  default     = []
}

variable "dependabot_app_id" {
  type        = number
  description = <<-EOT
    App ID of the jonomait-dependabot GitHub App (Settings → Developer settings → GitHub Apps →
    App ID; not the Client ID). On repos whose main needs approvals, it may merge a PR without the
    review: the pipelines dependabot-auto-merge workflow uses it only for patch and minor Dependabot
    updates, after the required checks passed. Its key lives only in Dependabot secrets, so no other
    workflow can use the bypass. null = no bypass.
  EOT
  default     = null
}

variable "repositories" {
  description = <<-EOT
    Every repo of the org, by name. The standard (squash only, branch deleted on merge, auto-merge,
    secret scanning, Dependabot, protected main) is the same for all; a repo only says what it is
    and which checks guard its main branch.
      kind               platform | library | template | app (becomes the topic layer-<kind>)
      checks             required status checks on main (exact check names)
      approvals          required approving reviews on main (0 while one person runs the org)
      code_owner_review  require a CODEOWNERS review on main
      release_tags       protect release tags (v*, <module>/v*) from deletion and moves
  EOT
  type = map(object({
    description       = string
    kind              = string
    homepage          = optional(string)
    topics            = optional(list(string), [])
    is_template       = optional(bool, false)
    checks            = optional(list(string), [])
    approvals         = optional(number, 0)
    code_owner_review = optional(bool, false)
    release_tags      = optional(bool, false)
  }))

  validation {
    condition     = alltrue([for r in values(var.repositories) : contains(["platform", "library", "template", "app"], r.kind)])
    error_message = "kind must be platform, library, template or app."
  }

  validation {
    condition     = alltrue([for r in values(var.repositories) : length(r.checks) > 0])
    error_message = "Every repo needs at least one required check on main: a main nobody verifies is not protected."
  }
}
