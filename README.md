# organization

JonomaIT AWS organization governance in Terraform: everything the organization needs that Control Tower does not do, and the access every pipeline uses. It touches the most sensitive accounts, so it has the strictest review rules (few people with merge, code owners).

| Folder | What | Status |
|---|---|---|
| `bootstrap/` | Per account: GitHub OIDC provider, state bucket, pipeline roles | ready |
| `github/` | The GitHub org standard as code: Actions policy, every repo's settings, security and rulesets | ready |
| `org/` | SCPs, RCPs, extra OUs, permission sets, delegation of the security services | later |

**Separation of duties:** the `infrastructure` repo assumes the pipeline roles, but the code of those roles lives here. Whoever uses an access does not control it.

## Layout

```
organization/
├── bootstrap/
│   ├── *.tf
│   ├── platform.auto.tfvars       the platform's identity: prefix, region, GitHub org (every account)
│   ├── env/<account>.tfvars       which repos run Terraform in the account
│   └── tests/
└── .github/workflows/ci.yml       fmt, validate, tests (no AWS access)
```

State key convention: `<account>/<region|global|cross-region>/<component>`; bootstrap is `<account>/global/bootstrap`, in the account's own bucket, `<prefix>-<account>-tfstate`. The pipelines derive the same bucket from the `PROJECT_PREFIX` and `STATE_REGION` org variables: no backend files.

**Another platform** (another name, another GitHub organization): change `bootstrap/platform.auto.tfvars` and set the org variables `PROJECT_PREFIX` and `STATE_REGION` to the same `prefix` and `region`. Nothing else in the code names the platform.

## GitHub settings (`github/`)

One standard for every repo, so no setting depends on someone remembering to click it. `github.auto.tfvars` lists the repos and only what differs between them (kind, required checks, reviews, release tags); the rest is the same for all:

| Area | Standard |
|---|---|
| Merging | squash only, title = PR title (Conventional Commits feed the releases), auto-merge allowed, "update branch" button |
| Branches | head branch deleted on merge; `main` ruleset: no push, no delete, no force-push, PR with the repo's required checks passing on the latest `main`, threads resolved |
| Release tags | `v*` and `<module>/v*` cannot be moved or deleted (libraries) |
| Security | secret scanning + push protection, Dependabot alerts and security updates |
| Clutter | no wiki, no projects, no discussions: docs live in the repo, the backlog in issues |
| Topics | `layer-<kind>` plus the repo's own, so the org page filters by layer |
| Actions (org) | only GitHub's actions, verified creators and the listed patterns; `GITHUB_TOKEN` read-only by default |

Removing a repo from the list **archives** it (never deletes it), and `prevent_destroy` stops even that unless the line is removed on purpose. `imports.tf` adopts the repos and rulesets that already exist; delete it after the first apply.

Applied by hand by an org owner, like the bootstrap (the state lives in the management account):

```bash
gh auth refresh -s admin:org                            # the token needs org admin
export GITHUB_TOKEN=$(gh auth token)
export AWS_PROFILE=jonomait-management

cd github
terraform init -reconfigure \
  -backend-config=bucket=jonomait-management-tfstate -backend-config=region=us-east-1 \
  -backend-config=key=management/global/github
terraform plan                                           # read it: imports, then only setting changes
terraform apply
```

A new repo: create it on GitHub, add its entry to `github.auto.tfvars`, apply.

## Bootstrap

Applied **by hand, once per account**, by someone with administrative access there: no pipeline can create the role it will itself use. Every account gets:

| Resource | Name |
|---|---|
| GitHub OIDC provider | `token.actions.githubusercontent.com` |
| State bucket (versioned, KMS, HTTPS only) | `<prefix>-<account>-tfstate` (e.g. `jonomait-staging-tfstate`) |
| Write role, per repo | `github-actions-<repo>`: `AdministratorAccess`, trusts only jobs in the GitHub Environment named after the account |
| Plan role, per repo | `github-actions-<repo>-plan`: `ReadOnlyAccess` + the S3 lock files, trusts pull requests and `main` (plan before approval, drift check) |
| Image push (shared-services only) | `github-actions-ecr-push`: any org repo, `main` only |

Which repos run in each account is the only thing a tfvars declares:

| Account | Repos |
|---|---|
| `management`, `audit` | `organization` |
| `shared-services`, `staging`, `production` | `infrastructure` |
| `log-archive` | none: managed by Control Tower |

**Why the write role is `AdministratorAccess`:** a Terraform pipeline creates whatever the code declares, and an allow list per service would need a bootstrap change for every new resource. It is limited instead by its trust (only this account's GitHub Environment, with required reviewers in production), by the organization's SCPs (which do not apply to the management account, where only this repo runs) and by pull requests only ever reaching the read-only plan role.

### First run in an account

The state bucket does not exist yet, so the first apply runs with local state and then moves it into the bucket it created. Example for `staging`:

```bash
aws sso login --sso-session jonomait
export AWS_PROFILE=jonomait-staging                     # the profile decides WHERE

cd bootstrap
mv backend.tf backend.tf.off                           # 1. local state for the first run
terraform init
terraform apply -var-file=env/staging.tfvars           # the tfvars decides WHAT
mv backend.tf.off backend.tf                           # 2. move the state into the new bucket
terraform init -migrate-state \
  -backend-config=bucket=jonomait-staging-tfstate -backend-config=region=us-east-1 \
  -backend-config=key=staging/global/bootstrap
rm -f terraform.tfstate*                               # 3. the state now lives in S3
```

### Later runs

```bash
export AWS_PROFILE=jonomait-staging
terraform init -reconfigure \
  -backend-config=bucket=jonomait-staging-tfstate -backend-config=region=us-east-1 \
  -backend-config=key=staging/global/bootstrap
terraform plan -var-file=env/staging.tfvars            # platform.auto.tfvars is loaded by itself
```

`-reconfigure` is required when switching accounts in the same directory: without it, `plan` uses the previous account's state.

### Tests

The convention tests run against each account's tfvars with a mocked AWS provider (no credentials):

```bash
cd bootstrap
terraform init -backend=false
for f in env/*.tfvars; do terraform test -var-file="$f"; done
```

They check the role names, that the write role trusts only the account's GitHub Environment, that the plan role trusts only pull requests and main, the state bucket name and that `github-actions-ecr-push` exists only in shared-services. CI runs the same on every pull request.

### Next step: no manual runs

Only the first run in `management` has to stay manual (it creates this repo's own role). After that, this repo's pipeline can apply `bootstrap` to every other account by assuming `AWSControlTowerExecution`, the role Control Tower creates in each account it manages, so a new account from Account Factory is born ready for its pipelines.
