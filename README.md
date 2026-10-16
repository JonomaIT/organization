# organization

JonomaIT AWS organization governance in Terraform: everything the organization needs that Control Tower does not do, and the access every pipeline uses. It touches the most sensitive accounts, so it has the strictest review rules (few people with merge, code owners).

| Folder | What | Status |
|---|---|---|
| `bootstrap/` | Per account: GitHub OIDC provider, state bucket, pipeline roles | ready |
| `org/` | SCPs, RCPs, extra OUs, permission sets, delegation of the security services | later |

**Separation of duties:** the `infrastructure` repo assumes the pipeline roles, but the code of those roles lives here. Whoever uses an access does not control it.

## Layout

```
organization/
├── backends/<account>.tfbackend   state bucket of each account
├── bootstrap/
│   ├── *.tf
│   ├── env/<account>.tfvars       which repos run Terraform in the account
│   └── tests/
└── .github/workflows/ci.yml       fmt, validate, tests (no AWS access)
```

State key convention: `<account>/<region|global|cross-region>/<component>`; bootstrap is `<account>/global/bootstrap`, in the account's own bucket.

## Bootstrap

Applied **by hand, once per account**, by someone with administrative access there: no pipeline can create the role it will itself use. Every account gets:

| Resource | Name |
|---|---|
| GitHub OIDC provider | `token.actions.githubusercontent.com` |
| State bucket (versioned, KMS, HTTPS only) | `jonomait-<account>-tfstate` |
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
  -backend-config=../backends/staging.tfbackend \
  -backend-config=key=staging/global/bootstrap
rm -f terraform.tfstate*                               # 3. the state now lives in S3
```

### Later runs

```bash
export AWS_PROFILE=jonomait-staging
terraform init -reconfigure \
  -backend-config=../backends/staging.tfbackend \
  -backend-config=key=staging/global/bootstrap
terraform plan -var-file=env/staging.tfvars
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
