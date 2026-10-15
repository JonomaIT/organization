output "state_bucket" {
  description = "State bucket of this account"
  value       = aws_s3_bucket.state.bucket
}

output "write_role_arns" {
  description = "Write roles, per repository (this account's GitHub Environment only)"
  value       = { for repo, r in aws_iam_role.write : repo => r.arn }
}

output "plan_role_arns" {
  description = "Read-only roles, per repository (pull requests only)"
  value       = { for repo, r in aws_iam_role.plan : repo => r.arn }
}

output "ecr_push_role_arn" {
  description = "Image push role for app repositories (null outside shared-services)"
  value       = one(aws_iam_role.ecr_push[*].arn)
}
