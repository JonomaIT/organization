output "repositories" {
  description = "Managed repos and their topics"
  value       = { for name, r in github_repository.repo : name => r.topics }
}
