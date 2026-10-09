# Amazon Q Developer Rules — AWS Well-Architected (terraform-aws-s3-module)

These rules map the six pillars of the [AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html)
and the [Amazon S3 security best practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html) to this module.
Use them when reviewing PRs that add or change features.

Severity: **MUST** = blocking review comment; **SHOULD** = non-blocking recommendation.

---

## 🔐 Security (SEC)
- SEC 7/8 (data at rest): default encryption MUST always be configured. SSE-KMS/DSSE-KMS SHOULD be used for confidential data. `deny_ssec_uploads` and `enforce_bucket_kms_key` MUST default to `true`.
- SEC 9 (data in transit): `enforce_tls` MUST default to `true` with `minimum_tls_version >= 1.2`.
- SEC 3 (permissions): new policy statements MUST be `Deny` guardrails, or `Allow` statements scoped to specific principals and conditions. Perimeter controls (`allowed_organization_id`, `allowed_vpc_endpoint_ids`) MUST exempt AWS service principals with `BoolIfExists aws:PrincipalIsAWSService = false`.
- The VPC-endpoint deny MUST always exempt the replication role, and SHOULD exempt a break-glass role (`vpce_policy_exempt_principal_arns`).
- SEC 10 (incident response / data protection): `enable_mfa_delete` requires versioning and the `mfa` variable. `mfa` MUST stay `sensitive = true` and MUST NOT be given a default, appear in examples, or be committed.
- Object Lock `COMPLIANCE` mode SHOULD be flagged in review because nobody, including root, can shorten it.
- IAM roles created by the module MUST be least privilege: name each action explicitly, scope resources to this bucket, the destination bucket and the specific KMS keys, and use `aws:SourceAccount` in trust policies.

## 🛟 Reliability (REL)
- REL 9 (backup): `enable_versioning` MUST default to `true`. Replication MUST require versioning (validated).
- `replication_replicate_delete_markers` MUST default to `false`, so replicas stay a protected copy.
- KMS-encrypted sources MUST replicate with `sse_kms_encrypted_objects` and a destination `replica_kms_key_id` (validated).
- Production buckets holding business-critical data SHOULD enable cross-region replication; recommend `replication_time_control` when RPO ≤ 15 minutes.
- `force_destroy` MUST default to `false`.

## ⚙️ Operational Excellence (OPS)
- OPS 4/8 (observability): `enable_eventbridge_notifications` defaults to `true`. Production SHOULD enable `enable_request_metrics` and `create_cloudwatch_alarms` with `alarm_actions`.
- Alarm resources MUST tag with `local.common_tags` and use `treat_missing_data = "notBreaching"`.
- Access logs SHOULD use `logging_partitioned_prefix = true` (Athena-friendly).
- S3 Inventory SHOULD be enabled for regulated data, so encryption, replication and Object Lock status can be audited.
- Every change MUST pass the CI gate (fmt/init/validate/plan, Checkov, Trivy, TFLint, Gitleaks) and `terraform test`.

## 💰 Cost Optimization (COST)
- COST 5/6: choose `storage_class` from the access pattern (see cost-and-operations.md). Versioned buckets SHOULD set `noncurrent_version_transition_days`, and MUST keep `noncurrent_version_expiration_days` non-null unless retention requirements say otherwise.
- Abort incomplete multipart uploads MUST always be configured.
- `bucket_key_enabled` MUST default to `true` for SSE-KMS.
- `replication_time_control` and `enable_request_metrics` add charges and MUST stay opt-in.
- Each PR's Infracost comment SHOULD be reviewed. Update `infracost-usage.yml` when usage assumptions change.

## ⚡ Performance Efficiency (PERF)
- `enable_transfer_acceleration` is for long-distance clients only, and is validated against dotted bucket names.
- Recommend CloudFront (with Origin Access Control) in front of the bucket for read-heavy global access, rather than public buckets.

## 🌱 Sustainability (SUS)
- SUS 4 (data): every bucket SHOULD have lifecycle rules that delete or archive data nobody needs; never keep noncurrent versions forever without a requirement.
- Prefer `INTELLIGENT_TIERING` when access patterns are unknown.

## Out of scope (recommend in review, don't implement here)
CloudTrail S3 data events, GuardDuty S3 Protection, Amazon Macie, AWS Config managed rules (`s3-bucket-*`), S3 Storage Lens, account-level Block Public Access, and AWS Backup for S3.
