# Amazon Q Developer Rules — Terraform Module Standards (terraform-aws-s3-module)

Based on [HashiCorp module structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure),
[AWS Prescriptive Guidance — Terraform best practices](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/introduction.html)
and the TFLint rules in `.tflint.hcl`.

---

## File structure (enforced by CI and pre-commit)
| Path | Purpose |
|---|---|
| `versions.tf` | `required_version` and `required_providers` only — no `provider` blocks in the module |
| `main.tf` | Locals, data sources, bucket core (ownership, BPA, versioning/MFA delete, Object Lock, encryption, CORS, acceleration, requester pays) |
| `kms.tf` | Optional customer managed key |
| `policy.tf` | Bucket policy guardrails |
| `lifecycle.tf` | Lifecycle rules and Intelligent-Tiering |
| `replication.tf` | Replication configuration and IAM role |
| `observability.tf` | Access logging, EventBridge, request metrics, alarms, inventory |
| `variables.tf` | All inputs, grouped: required → tagging → feature groups |
| `outputs.tf` | All outputs |
| `examples/{main,variables,outputs}.tf`, `examples/README.md` | Runnable root module used by CI `terraform plan` and Infracost |
| `tests/*.tftest.hcl` | Offline `terraform test` with `mock_provider "aws"` |
| `README.md` | Mandatory inputs, optional inputs, outputs, diagram |
| `.amazonq/rules/*.md` | These rules |
| `.pre-commit-config.yaml`, `.tflint.hcl`, `trivy.yaml` | Scanner configuration |

## Providers & regions
- MUST NOT declare `provider "aws"` inside the module; callers configure providers.
- Region selection MUST use the AWS provider v6 resource-level `region = var.aws_region` argument on **every** regional resource. Global resources (`aws_iam_role`, `aws_iam_role_policy`, `aws_iam_policy_document`) MUST NOT set `region`.
- `required_providers.aws.version` MUST stay `>= 6.0`; `required_version` MUST stay `>= 1.9.0` (cross-variable validation).

## Variables
- Every variable MUST have `description` and `type`; descriptions state allowed values and defaults' meaning.
- Constrained values MUST have a `validation` block with an actionable `error_message` that lists allowed values.
- Cross-variable rules (e.g. IA transition ≥ 30 days, CORS rules when CORS enabled) MUST be validations, not runtime `precondition`s, so they fail at `plan`.
- Use `optional()` with defaults in object types instead of `any`.
- Required inputs (no default): `bucket_name`, `aws_region`, `storage_class`, `enable_public_access_block`, `encryption_type`, `enable_cors`, `environment`, `project`, `owner`, `email`. Adding a new required input MUST update `examples/` and `README.md`.

## Resources
- Use `this` as the resource name for the single primary instance of each type.
- Optional resources MUST use `count = <bool> ? 1 : 0`; reference them with `try(x[0].attr, null)` in outputs.
- Use the split S3 resources (`aws_s3_bucket_*`). MUST NOT use deprecated inline `aws_s3_bucket` arguments (`acl`, `versioning`, `server_side_encryption_configuration`, `cors_rule`, `lifecycle_rule`, `logging`, `policy`).
- Lifecycle rules MUST be rendered from `local.lifecycle_rules` via a single `dynamic "rule"` block (avoids static-analyser rendering bugs with mixed static/dynamic blocks).
- IAM/KMS policies MUST be built with `data "aws_iam_policy_document"`, never `jsonencode` heredocs.

## Tagging
- All taggable resources MUST use `local.common_tags` (Name, Environment, Project, Owner, Email, ManagedBy) — enforced by TFLint `aws_resource_missing_tags`.
- Callers' `var.tags` MUST NOT override the mandatory tags (mandatory tags are merged last).

## Outputs
- Every output MUST have a `description`.
- Do not output secrets; mark any sensitive value `sensitive = true`.

## Formatting & quality gates
- `terraform fmt -recursive`, `terraform validate`, `tflint --recursive`, `checkov`, `trivy config`, `gitleaks` and `terraform test` MUST pass before merge.
- Use `snake_case` for all identifiers.
- Keep comments explaining *why*, not *what*.

## CI/CD
- Pull requests into `dev`, `qa` or `main` MUST pass the `CI Gate` status check (see `.github/workflows/`).
- Never commit `.terraform/`, `*.tfstate`, `*.tfplan` or `*.tfvars`.
