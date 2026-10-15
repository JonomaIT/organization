# One GitHub OIDC provider per account: a GitHub Actions job exchanges its token for temporary
# credentials of a role below, so no access key ever exists.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}
