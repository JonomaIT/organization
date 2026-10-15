# Pipeline roles, one pair per repository in var.repos, named by convention so a workflow builds
# the ARN on its own:
#   github-actions-<repo>        write: jobs that declare this account's GitHub Environment
#   github-actions-<repo>-plan   read-only: pull requests
#
# The write role has AdministratorAccess: a Terraform pipeline creates whatever the code declares,
# and an allow list per service would need a bootstrap change for every new resource. What limits
# it instead:
#   - its trust: only jobs in this account's GitHub Environment (required reviewers in production);
#   - the organization's SCPs (Control Tower controls, region deny), which bind even an admin.
#     They do not apply to the management account: only the organization repo runs there, with
#     the strictest review rules;
#   - a pull request can change the workflow it runs with, so it only ever reaches the plan role.

locals {
  # Two OIDC subject formats per repository: the immutable one (numeric IDs: a repo or org
  # recreated with the same name cannot match it), once the repo ID is known, and the classic one.
  subjects = {
    for repo, id in var.repos : repo => concat(
      id == null ? [] : ["repo:${var.github_org}@${var.github_org_id}/${repo}@${id}"],
      ["repo:${var.github_org}/${repo}"],
    )
  }
}

# ------------------------------------------------------------------ write
data "aws_iam_policy_document" "trust_write" {
  for_each = var.repos

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # A job that declares a GitHub Environment gets environment:<name> in its subject.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for s in local.subjects[each.key] : "${s}:environment:${var.environment}"]
    }
  }
}

resource "aws_iam_role" "write" {
  for_each = var.repos

  name                 = "github-actions-${each.key}"
  description          = "Terraform apply for ${var.github_org}/${each.key}, GitHub Environment ${var.environment} only"
  assume_role_policy   = data.aws_iam_policy_document.trust_write[each.key].json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "write" {
  for_each = var.repos

  role       = aws_iam_role.write[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ------------------------------------------------------------------- plan
data "aws_iam_policy_document" "trust_plan" {
  for_each = var.repos

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for s in local.subjects[each.key] : "${s}:pull_request"]
    }
  }
}

resource "aws_iam_role" "plan" {
  for_each = var.repos

  name                 = "github-actions-${each.key}-plan"
  description          = "Terraform plan for ${var.github_org}/${each.key} pull requests (read-only)"
  assume_role_policy   = data.aws_iam_policy_document.trust_plan[each.key].json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "plan" {
  for_each = var.repos

  role       = aws_iam_role.plan[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# ReadOnlyAccess already reads the state. With use_lockfile even a plan creates and deletes
# <key>.tflock next to the state, so the plan role writes those files and nothing else.
data "aws_iam_policy_document" "plan_lock" {
  statement {
    sid       = "StateLockFiles"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/*.tflock"]
  }
}

resource "aws_iam_role_policy" "plan_lock" {
  for_each = var.repos

  name   = "terraform-state-lock"
  role   = aws_iam_role.plan[each.key].id
  policy = data.aws_iam_policy_document.plan_lock.json
}
