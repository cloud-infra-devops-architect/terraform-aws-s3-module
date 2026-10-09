# 🧪 Example: complete S3 bucket

This example deploys a bucket with these settings:
- 🗄️ **INTELLIGENT_TIERING** from day 0
- 🔐 **SSE-KMS** with a module-created CMK (rotation on, Bucket Key on)
- 🚫 **Block Public Access** turned on
- 🔀 **CORS** for `https://app.example.com` (GET and HEAD)
- 🗂️ Versioning, with noncurrent versions moved to GLACIER_IR after 30 days and deleted after 365 days
- ⛔ Bucket policy that requires TLS 1.2+, denies SSE-C and denies uploads that name a different KMS key
- 📣 EventBridge notifications, plus 📈 CloudWatch request metrics with 4xx/5xx alarms
- 🔑 MFA delete, 🧷 Object Lock, 🏢 Organization perimeter and 🔁 replication are available as variables (off by default)

CI uses this example for `terraform init/validate/plan` and for the Infracost estimate.

## ▶️ Run

```bash
cd examples
terraform init
terraform plan  -var="bucket_name=<globally-unique-name>"
terraform apply -var="bucket_name=<globally-unique-name>"
```

Turn on MFA delete. This needs **root** credentials and the root MFA device:

```bash
TF_VAR_mfa="arn:aws:iam::<account-id>:mfa/root-account-mfa-device 123456" \
  terraform apply -var="bucket_name=<name>" -var="enable_mfa_delete=true"
```

Try other options by overriding the defaults:

```bash
terraform plan \
  -var="bucket_name=my-unique-bucket-123" \
  -var="aws_region=eu-west-1" \
  -var="storage_class=STANDARD_IA" \
  -var="storage_class_transition_days=30" \
  -var="encryption_type=SSE-S3" \
  -var="enable_cors=false"
```

## 📥 Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `bucket_name` | `string` | `"evolv-example-s3-module-dev-bucket"` | Globally unique bucket name |
| `aws_region` | `string` | `"us-east-1"` | Provider and bucket region |
| `storage_class` | `string` | `"INTELLIGENT_TIERING"` | Target storage class |
| `storage_class_transition_days` | `number` | `0` | Days before the transition |
| `enable_public_access_block` | `bool` | `true` | Attach Block Public Access |
| `encryption_type` | `string` | `"SSE-KMS"` | `SSE-S3`, `SSE-KMS` or `DSSE-KMS` |
| `kms_key_arn` | `string` | `null` | Existing KMS key. When `null`, the module creates one |
| `enable_cors` | `bool` | `true` | Apply CORS |
| `cors_rules` | `list(object)` | one GET/HEAD rule | CORS rules |
| `enable_versioning` | `bool` | `true` | Versioning |
| `enable_access_logging` | `bool` | `false` | Server access logging |
| `logging_target_bucket` | `string` | `null` | Log bucket |
| `force_destroy` | `bool` | `false` | Delete the bucket even if it has objects |
| `environment` | `string` | `"dev"` | Environment tag |
| `project` | `string` | `"terraform-aws-s3-module"` | Project tag |
| `owner` | `string` | `"platform-engineering"` | Owner tag |
| `email` | `string` | `"platform-engineering@example.com"` | Email tag |
| `tags` | `map(string)` | `{ CostCenter = "cloud-platform" }` | Extra tags |
| `enable_mfa_delete` | `bool` | `false` | MFA delete (root user only) |
| `mfa` | `string` (sensitive) | `null` | `"<root-mfa-serial> <code>"`, passed with `TF_VAR_mfa` |
| `object_lock_enabled` | `bool` | `false` | Object Lock (only at bucket creation) |
| `object_lock_default_retention_mode` | `string` | `null` | `GOVERNANCE` or `COMPLIANCE` |
| `object_lock_default_retention_days` | `number` | `null` | Default retention in days |
| `allowed_organization_id` | `string` | `null` | Organization perimeter |
| `enable_replication` | `bool` | `false` | Replication |
| `replication_destination_bucket_arn` | `string` | `null` | Replica bucket ARN |
| `replication_destination_kms_key_arn` | `string` | `null` | Replica KMS key (required for SSE-KMS) |
| `noncurrent_version_transition_days` | `number` | `30` | Days before noncurrent versions move to GLACIER_IR |
| `enable_request_metrics` | `bool` | `true` | Request metrics and 4xx/5xx alarms |
| `alarm_actions` | `list(string)` | `[]` | SNS topics for the alarms |

## 📤 Outputs

| Name | Description |
|---|---|
| `bucket_id` | Bucket name |
| `bucket_arn` | Bucket ARN |
| `bucket_regional_domain_name` | Regional domain name |
| `bucket_region` | Bucket region |
| `sse_algorithm` | Encryption algorithm in effect |
| `kms_key_arn` | KMS key ARN (`null` for SSE-S3) |
| `kms_key_alias` | Alias of the module-created key |
| `versioning_status` | Versioning status |
| `lifecycle_rule_ids` | Lifecycle rules in effect |
| `cloudwatch_alarm_arns` | 4xx/5xx alarm ARNs |
| `mfa_delete_enabled` | Whether MFA delete is on |
| `replication_role_arn` | Replication role (`null` when replication is off) |
