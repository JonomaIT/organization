# audit: org-wide security services (delegated administrator). Only the organization repo runs here.
environment = "audit"

repos = {
  organization = null # repo ID once the repo exists: gh api repos/JonomaIT/organization -q .id
}
