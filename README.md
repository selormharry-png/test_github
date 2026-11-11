# EC2 on AWS with Terraform — DevSecOps Pipeline

Provisions an Amazon EC2 instance on AWS with Terraform. Deployment runs through a
GitHub Actions pipeline that scans for secrets, lint errors and security
misconfigurations before any change reaches AWS. Terraform state is kept in an
encrypted, versioned S3 bucket with native state locking.

## Architecture

```
            ┌────────────────────────── GitHub Actions ──────────────────────────┐
 git push → │ Gitleaks ─┐                                                         │
            │ Lint ─────┼─► Plan ─► [manual approval] ─► Apply ─► EC2 instance    │
            │ Checkov ──┘     │                                                   │
            └─────────────────┼───────────────────────────────────────────────────┘
                              ▼
                 S3 bucket (Terraform state, locked with use_lockfile)
```

## Repository layout

```
.
├── bootstrap/                  # One-time setup: S3 bucket that stores Terraform state
│   ├── main.tf                 # Bucket, versioning, encryption, public-access block, ownership controls
│   ├── variables.tf            # Bucket name, region, AWS CLI profile
│   ├── providers.tf            # Terraform/AWS provider versions
│   └── output.tf               # Outputs the bucket name
├── venv/                       # Main infrastructure (deployed by the pipeline)
│   ├── main.tf                 # EC2 instance
│   ├── versions.tf             # Amazon Linux 2 AMI lookup
│   ├── variables.tf            # Instance type
│   ├── outputs.tf              # Instance ID
│   ├── providers.tf            # Terraform/AWS provider versions
│   ├── backend.tf              # S3 remote state backend
│   └── moved.tf                # State address refactors
├── .github/workflows/
│   └── terraform.yml           # DevSecOps CI/CD pipeline
└── .pre-commit-config.yaml     # Local security & lint checks before commit
```

## Prerequisites

| Tool | Version |
|------|---------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.10 (needed for S3 native locking) |
| [AWS CLI](https://aws.amazon.com/cli/) | v2, with a configured profile |
| [pre-commit](https://pre-commit.com/) | latest (optional, for local checks) |
| [TFLint](https://github.com/terraform-linters/tflint), [Checkov](https://www.checkov.io/) | latest (optional, used by pre-commit) |

You also need an AWS account with permission to create S3 buckets, EC2 instances
and IAM roles.

## Getting started

### 1. Create the state bucket (one time)

The state bucket lives in a separate Terraform configuration. Terraform can't
create the bucket that stores its own state, because the backend has to exist
before `terraform init` runs.

```bash
cd bootstrap
terraform init
terraform plan
terraform apply
```

Settings are in `bootstrap/variables.tf`:

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_bucket_name` | `bootstrap124` | Globally unique S3 bucket name |
| `aws_region` | `eu-central-1` | AWS region |
| `aws_profile_name` | `safe-safe` | Local AWS CLI profile |

The bucket is created with:
- versioning, so previous state versions can be recovered
- AES-256 server-side encryption
- all public access blocked
- `BucketOwnerEnforced` ownership, so ACLs are disabled
- `prevent_destroy`, to protect it from accidental deletion

### 2. Configure the backend

Set the bucket name in `venv/backend.tf` to match the bucket from step 1:

```hcl
terraform {
  backend "s3" {
    bucket       = "<your-state-bucket>"
    key          = "ec2/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

### 3. Deploy locally (optional)

```bash
cd venv
export AWS_PROFILE=<your-profile>
export AWS_REGION=eu-central-1
terraform init
terraform plan
terraform apply
```

| Variable | Default | Description |
|----------|---------|-------------|
| `instance_type` | `t3.micro` | EC2 instance type |

## CI/CD pipeline

`.github/workflows/terraform.yml` runs on pushes and pull requests to `main`, and
can also be started manually.

| Stage | Tool | Purpose |
|-------|------|---------|
| Secrets scan | Gitleaks | Blocks committed credentials, scanning the full git history |
| Lint & validate | `terraform fmt`, `terraform validate`, TFLint | Formatting, syntax and best practices |
| IaC security scan | Checkov | Finds misconfigurations; results go to the GitHub Security tab |
| Plan | Terraform | Plans against real state and saves the plan as an artifact |
| Apply | Terraform | Applies the exact saved plan, only on `main`, after manual approval |

On a pull request, everything up to and including **Plan** runs. **Apply** only
runs after a merge to `main`.

### Pipeline setup

1. **AWS OIDC.** Create a GitHub OIDC identity provider in IAM and a role that
   trusts this repository. The role needs read/write access to the state bucket
   and EC2 permissions. No long-lived access keys are used.
2. **Repository secret.** Add `AWS_ROLE_ARN` under
   *Settings → Secrets and variables → Actions*.
3. **Approval gate.** Create a `production` environment under
   *Settings → Environments* and add required reviewers.
4. **Branch protection (recommended).** Require the scan and plan jobs to pass
   before merging to `main`.

## Local security checks (pre-commit)

The same checks as the pipeline can run on your machine before every commit:

```bash
pip install pre-commit checkov
pre-commit install
pre-commit run --all-files    # first full scan
```

Pre-commit gives quick feedback but can be skipped with `--no-verify`. The CI
pipeline is the check that is enforced.

## Security practices

- Remote state is encrypted, versioned and locked.
- The state bucket is kept separate from application infrastructure.
- CI authenticates to AWS with OIDC, so no static credentials are stored.
- Each job has least-privilege permissions.
- Secrets, lint and IaC scans run before every plan.
- A human approves every apply to production.

## Clean up

```bash
cd venv
terraform destroy
```

The state bucket has `prevent_destroy` enabled. To delete it, remove that
lifecycle rule, empty the bucket, including all object versions, and then run
`terraform destroy` in `bootstrap/`.

## License

MIT
