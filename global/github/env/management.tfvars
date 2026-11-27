# The org's repos and what makes each one different; everything else is the standard
# (repositories.tf, rulesets.tf). A new repo is one entry here, applied by the Deploy pipeline.
# The file is named after the account that keeps the state (management), as every global component.
github_org = "JonomaIT"

allowed_action_patterns = [
  "googleapis/release-please-action@*",
]

# jonomait-dependabot app (App ID, not secret): may merge Dependabot patch/minor PRs without the
# review on repos that need approvals.
dependabot_app_id = 5958542

repositories = {
  organization = {
    description = "JonomaIT AWS organization governance: per-account bootstrap (GitHub OIDC, state bucket, pipeline roles)"
    kind        = "platform"
    topics      = ["terraform", "aws", "governance"]
    checks      = ["terraform / fmt · validate · test", "terraform / security scan"]
  }
  infrastructure = {
    description = "JonomaIT platform foundation in Terraform: network, ECS cluster, shared ALB, ECR and the Cloudflare entry, per account and region"
    kind        = "platform"
    topics      = ["terraform", "aws", "cloudflare"]
    checks      = ["terraform / fmt · validate · test", "terraform / security scan", "deploy / Plan result"]
  }
  "terraform-modules" = {
    description  = "JonomaIT Terraform module library: primitives (VPC, ECS cluster, ALB), app patterns (ECS service, static site, DNS) and multi-region data modules"
    kind         = "library"
    topics       = ["terraform", "aws", "cloudflare", "terraform-modules"]
    checks       = ["terraform / fmt · validate · test", "terraform / security scan", "module READMEs up to date"]
    release_tags = true
  }
  pipelines = {
    description  = "JonomaIT runners that turn an app's values into a running app (ECS runner on the ecs-service pattern)"
    kind         = "library"
    topics       = ["github-actions", "terraform", "ci-cd"]
    checks       = ["actionlint", "terraform / fmt · validate · test", "terraform / security scan"]
    release_tags = true
  }
  "template-web-react" = {
    description       = "JonomaIT template for web apps (web-*): React, TypeScript, Vite and Cloudscape"
    kind              = "template"
    topics            = ["react", "cloudfront", "template"]
    is_template       = true
    checks            = ["site / lint · test · build"]
    approvals         = 1
    code_owner_review = true
  }
  "svc-sales-api" = {
    description       = "Sales API: stores sales and publishes them for processing, active in two regions (JonomaIT lab)"
    kind              = "app"
    topics            = ["ecs", "python", "reference"]
    checks            = ["image / build · scan · push"]
    approvals         = 1
    code_owner_review = true
  }
  "svc-sales-worker" = {
    description       = "Sales processor: consumes every region's sales, only in the ACTIVE region, idempotent (JonomaIT lab)"
    kind              = "app"
    topics            = ["ecs", "python", "reference"]
    checks            = ["image / build · scan · push"]
    approvals         = 1
    code_owner_review = true
  }
  "web-sales" = {
    description       = "Sales simulator: create sales and watch them processed across two regions (JonomaIT lab, CloudFront)"
    kind              = "app"
    homepage          = "https://vendas.joshuel.com.br"
    topics            = ["cloudfront", "react", "reference"]
    checks            = ["site / lint · test · build"]
    approvals         = 1
    code_owner_review = true
  }
  "web-joshuel" = {
    description = "Personal site at joshuel.com.br"
    kind        = "app"
    homepage    = "https://joshuel.com.br"
    topics      = ["cloudfront", "static-site", "personal"]
    checks      = ["app contract"]
  }
  "web-english" = {
    description = "English study site at english.joshuel.com.br"
    kind        = "app"
    homepage    = "https://english.joshuel.com.br"
    topics      = ["cloudfront", "lambda", "personal"]
    checks      = ["site / lint · test · build"]
  }
  "web-dra-leticia" = {
    description = "Site da Dra. Letícia Penin (draleticiapenin.com.br) na plataforma JonomaIT"
    kind        = "app"
    homepage    = "https://draleticiapenin.com.br"
    topics      = ["cloudfront", "static-site", "client"]
    checks      = ["app contract"]
  }
}
