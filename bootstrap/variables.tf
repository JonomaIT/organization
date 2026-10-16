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
variable "prefix" {
  type        = string
  description = "Project prefix; the state bucket is <prefix>-<environment>-tfstate"
  default     = "jonomait"
}

variable "region" {
  type        = string
  description = "Region of the state bucket and of the API calls (IAM itself is global)"
  default     = "us-east-1"
}

variable "github_org" {
  type        = string
  description = "GitHub organization whose repositories may assume the roles"
  default     = "JonomaIT"
}

variable "github_org_id" {
  type        = string
  description = "Numeric ID of the GitHub organization (gh api orgs/<org> -q .id)"
  default     = "330996477"
}
