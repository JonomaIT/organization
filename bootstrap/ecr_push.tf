# Image push for app repositories, only in shared-services (where ECR lives). Images are built
# once on main and promoted to staging and production, so only main pushes. It cannot create or
# delete repositories: that is the infrastructure pipeline.
# Next step: restrict to the platform's reusable workflow (job_workflow_ref in the OIDC subject), so
# an app repo cannot push with a workflow of its own.

locals {
  ecr_push = var.environment == "shared-services"
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "trust_ecr_push" {
  count = local.ecr_push ? 1 : 0

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
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org}@${var.github_org_id}/*:ref:refs/heads/main",
        "repo:${var.github_org}/*:ref:refs/heads/main",
      ]
    }
  }
}

data "aws_iam_policy_document" "ecr_push" {
  count = local.ecr_push ? 1 : 0

  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:DescribeImages",
    ]
    resources = ["arn:aws:ecr:*:${data.aws_caller_identity.current.account_id}:repository/*"]
  }
}

resource "aws_iam_role" "ecr_push" {
  count = local.ecr_push ? 1 : 0

  name                 = "github-actions-ecr-push"
  description          = "Image push for ${var.github_org} app repositories (main only)"
  assume_role_policy   = data.aws_iam_policy_document.trust_ecr_push[0].json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "ecr_push" {
  count = local.ecr_push ? 1 : 0

  name   = "ecr-push"
  role   = aws_iam_role.ecr_push[0].id
  policy = data.aws_iam_policy_document.ecr_push[0].json
}
