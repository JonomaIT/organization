# Naming and trust conventions, checked against each account's tfvars without touching AWS:
#   for f in env/*.tfvars; do terraform test -var-file="$f"; done

mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
}

run "roles_follow_the_naming_convention" {
  command = plan

  assert {
    condition     = alltrue([for repo in keys(var.repos) : aws_iam_role.write[repo].name == "github-actions-${repo}"])
    error_message = "Every repo needs a write role named github-actions-<repo>."
  }

  assert {
    condition     = alltrue([for repo in keys(var.repos) : aws_iam_role.plan[repo].name == "github-actions-${repo}-plan"])
    error_message = "Every repo needs a plan role named github-actions-<repo>-plan."
  }
}

run "write_trusts_only_this_accounts_environment" {
  command = plan

  assert {
    condition = alltrue(flatten([
      for repo, d in data.aws_iam_policy_document.trust_write : [
        for v in one([for c in one(d.statement).condition : c.values if c.variable == "token.actions.githubusercontent.com:sub"]) :
        endswith(v, ":environment:${var.environment}")
      ]
    ]))
    error_message = "The write role must only trust jobs in this account's GitHub Environment."
  }

  assert {
    condition = alltrue(flatten([
      for repo, d in data.aws_iam_policy_document.trust_plan : [
        for v in one([for c in one(d.statement).condition : c.values if c.variable == "token.actions.githubusercontent.com:sub"]) :
        endswith(v, ":pull_request")
      ]
    ]))
    error_message = "The plan role must only trust pull requests."
  }
}

run "state_bucket_and_ecr_push" {
  command = plan

  assert {
    condition     = aws_s3_bucket.state.bucket == "jonomait-${var.environment}-tfstate"
    error_message = "The state bucket must be jonomait-<account>-tfstate."
  }

  assert {
    condition     = length(aws_iam_role.ecr_push) == (var.environment == "shared-services" ? 1 : 0)
    error_message = "github-actions-ecr-push exists only in shared-services."
  }
}
