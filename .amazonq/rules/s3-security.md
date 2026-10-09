# Amazon Q Developer Rules — S3 Security (terraform-aws-s3-module)

These rules guide Amazon Q when reviewing, generating, or modifying Terraform code in this repository.
They are derived from the AWS Well-Architected Security Pillar, the
[Amazon S3 security best practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html),
CIS AWS Foundations Benchmark (S3 controls) and AWS Foundational Security Best Practices (Security Hub S3.x).

Severity: **MUST** = blocking review comment; **SHOULD** = non-blocking recommendation.

---

## 1. Block Public Access (Security Hub S3.1 / S3.8, CIS 2.1.4)
- MUST keep `enable_public_access_block` defaulting to the safe value in examples (`true`) and all four flags (`block_public_acls`, `block_public_policy`, `ignore_public_acls`, `restrict_public_buckets`) defaulting to `true`.
- MUST NOT add `aws_s3_bucket_acl` resources granting `public-read`, `public-read-write` or `authenticated-read`.
- MUST NOT add bucket policy statements with `Principal = "*"` and `Effect = "Allow"` unless constrained by `aws:SourceVpce`, `aws:SourceArn`, `aws:PrincipalOrgID` or `aws:SourceAccount` conditions.
- The bucket policy MUST `depends_on` the public access block so a permissive caller policy is rejected, not applied.

## 2. Encryption at rest (Security Hub S3.4 / S3.17, CIS 2.1.1)
- Every bucket MUST have an `aws_s3_bucket_server_side_encryption_configuration`.
- `encryption_type` MUST be validated to `SSE-S3`, `SSE-KMS` or `DSSE-KMS`; never accept free-text algorithms.
- Module-created KMS keys MUST set `enable_key_rotation = true`, a `deletion_window_in_days` of 7–30, and an explicit key `policy`.
- KMS key policies MUST NOT grant `kms:*` to any principal other than the account root.
- `bucket_key_enabled` SHOULD be `true` for SSE-KMS to reduce KMS request cost; it MUST be `null` for DSSE-KMS (unsupported).
- Do not set `kms_master_key_id` when the algorithm is `AES256`.

## 2a. Upload guardrails
- `deny_ssec_uploads` MUST default to `true` (SSE-C bypasses KMS key policies and auditing).
- `enforce_bucket_kms_key` MUST default to `true`. It denies only uploads that explicitly request a different KMS key.

## 3. Encryption in transit (Security Hub S3.5)
- `enforce_tls` MUST default to `true`; the bucket policy MUST deny `aws:SecureTransport = false`.
- The minimum TLS version MUST be `1.2` or higher (`s3:TlsVersion` `NumericLessThan`).

## 4. Access control
- `object_ownership` MUST default to `BucketOwnerEnforced` (ACLs disabled) — Security Hub S3.12.
- Prefer IAM / bucket policies over ACLs; do not introduce `grant` blocks.
- Caller-supplied policy JSON MUST be merged with `source_policy_documents`, never string-concatenated.
- Never hardcode account IDs, ARNs or principals — use `data.aws_caller_identity`, `data.aws_partition` or variables.

## 5. Data protection & recovery
- `enable_versioning` MUST default to `true` (Security Hub S3.14).
- MFA delete (`enable_mfa_delete`) MUST require versioning and the sensitive `mfa` variable. Never set `mfa_delete` without the `mfa` token (S3 rejects it).
- Object Lock default retention MUST set exactly one of days or years (validated). Security Hub S3.15 recommends Object Lock for immutable data.
- Replication (Security Hub S3.7) MUST use a least-privilege role and MUST NOT replicate delete markers by default.
- `force_destroy` MUST default to `false`.
- Object Lock MUST require versioning (enforced via variable validation).
- Lifecycle MUST always include an `abort_incomplete_multipart_upload` rule (Checkov CKV_AWS_300).

## 6. Logging & monitoring
- EventBridge notifications are on by default. Recommend 4xx/5xx alarms for production.
- Server access logging SHOULD be enabled for production buckets (`enable_access_logging = true`) — Security Hub S3.9.
- The log target bucket MUST differ from the source bucket (validated).
- Recommend CloudTrail data events for sensitive buckets (consumer responsibility; document, do not create here).

## 7. Secrets
- Never commit AWS access keys, secret keys, session tokens, `*.tfvars` or `*.tfstate` files.
- Gitleaks and the `detect-aws-credentials` pre-commit hook MUST remain enabled.

## 8. Scanner suppressions
- Every Checkov skip MUST be inline (`#checkov:skip=<ID>:<reason>`) on the specific resource.
- Every Trivy ignore MUST be in `.trivyignore` with a justification comment.
- Suppressions MUST NOT be added for: public access (CKV_AWS_53–56, CKV2_AWS_6), encryption in transit, versioning, or KMS rotation (CKV_AWS_7).
