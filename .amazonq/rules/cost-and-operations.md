# Amazon Q Developer Rules — Cost Optimization & Operational Excellence (terraform-aws-s3-module)

Derived from the AWS Well-Architected Cost Optimization, Reliability and Sustainability pillars and
[S3 storage classes guidance](https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-class-intro.html).

---

## Storage class selection
| Access pattern | Recommended `storage_class` | Notes |
|---|---|---|
| Unknown / changing | `INTELLIGENT_TIERING` | `storage_class_transition_days = 0`; optional archive tiers via `enable_intelligent_tiering_archive` |
| Frequent (daily) | `STANDARD` | No transition rule created |
| Infrequent, multi-AZ | `STANDARD_IA` | ≥ 30-day transition, 128 KB minimum billable object size |
| Infrequent, re-creatable | `ONEZONE_IA` | Single AZ — never for the only copy of critical data |
| Archive, ms retrieval | `GLACIER_IR` | 90-day minimum storage duration |
| Archive, minutes–hours | `GLACIER` | 90-day minimum |
| Long-term compliance | `DEEP_ARCHIVE` | 180-day minimum, 12 h retrieval |

- SHOULD warn when `ONEZONE_IA` is used with `environment = "prod"`.
- SHOULD warn when `object_expiration_days` is shorter than the minimum storage duration of `storage_class`.

## Cost controls
- `bucket_key_enabled = true` for SSE-KMS (reduces KMS requests up to 99%).
- Always abort incomplete multipart uploads (default 7 days).
- Expire noncurrent versions (default 90 days) when versioning is enabled.
- Every PR MUST show an Infracost estimate; usage assumptions live in `infracost-usage.yml`.

## Reliability
- Versioning on by default; `force_destroy = false` by default.
- Recommend Cross-Region Replication for business-critical data (consumer-owned; out of scope).

## Operations
- All resources tagged via `local.common_tags` for cost allocation (activate `Project`, `Environment`, `Owner` as cost allocation tags).
- Changes MUST be reviewed with `terraform plan` output posted to the PR by CI.
