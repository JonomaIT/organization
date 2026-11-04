variable "environment" {
  type        = string
  description = "The account this bootstrap runs in, named after its role in the organization"

  validation {
    condition = contains(
      ["management", "audit", "log-archive", "shared-services", "staging", "production"],
      var.environment
    )
    error_message = "environment must be one of: management, audit, log-archive, shared-services, staging, production."
  }
}

variable "repos" {
  type        = map(string)
  description = "Repositories that run Terraform in this account: name => numeric repo ID (gh api repos/<org>/<repo> -q .id), or null while the repo does not exist yet"
  default     = {}
}

# ------------------------------------------------- the same in every account
# No defaults: the platform's identity lives in platform.auto.tfvars (loaded automatically), so the
# same code bootstraps another platform by changing that one file.
variable "prefix" {
  type        = string
  description = "Platform prefix: the state bucket is <prefix>-<environment>-tfstate, tags are <prefix>:*. The same value as the PROJECT_PREFIX org variable"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,14}$", var.prefix))
    error_message = "prefix must be 2-15 lowercase letters and digits."
  }
}

variable "region" {
  type        = string
  description = "Region of the state bucket and of the API calls (IAM itself is global). The same value as the STATE_REGION org variable"
}

variable "github_org" {
  type        = string
  description = "GitHub organization whose repositories may assume the roles"
}

variable "github_org_id" {
  type        = string
  description = "Numeric ID of the GitHub organization (gh api orgs/<org> -q .id): the immutable OIDC subject"

  validation {
    condition     = can(regex("^[0-9]+$", var.github_org_id))
    error_message = "github_org_id is the numeric ID (gh api orgs/<org> -q .id)."
  }
}
