# production: workload account (Workloads/Prod OU).
environment = "production"

# Apps get the same pair of roles as infrastructure: deploy-app (pipelines) assumes
# github-actions-<app> inside the production GitHub Environment.
repos = {
  infrastructure   = "1409591232"
  svc-sales-api    = "1427758242"
  svc-sales-worker = "1427758316"
  web-sales        = "1427788935"
}
