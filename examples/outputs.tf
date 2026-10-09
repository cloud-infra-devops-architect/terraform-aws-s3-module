output "bucket_id" {
  description = "Name (ID) of the S3 bucket."
  value       = module.s3_bucket.bucket_id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket."
  value       = module.s3_bucket.bucket_arn
}

output "bucket_regional_domain_name" {
  description = "Region-specific domain name of the bucket."
  value       = module.s3_bucket.bucket_regional_domain_name
}

output "bucket_region" {
  description = "AWS region of the bucket."
  value       = module.s3_bucket.bucket_region
}

output "sse_algorithm" {
  description = "Server-side encryption algorithm in effect."
  value       = module.s3_bucket.sse_algorithm
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for default encryption (null for SSE-S3)."
  value       = module.s3_bucket.kms_key_arn
}

output "kms_key_alias" {
  description = "Alias of the module-created KMS key (null when not created)."
  value       = module.s3_bucket.kms_key_alias
}

output "versioning_status" {
  description = "Versioning status of the bucket."
  value       = module.s3_bucket.versioning_status
}

output "lifecycle_rule_ids" {
  description = "Lifecycle rules applied to the bucket."
  value       = module.s3_bucket.lifecycle_rule_ids
}

output "cloudwatch_alarm_arns" {
  description = "CloudWatch alarm ARNs for 4xx/5xx errors."
  value       = module.s3_bucket.cloudwatch_alarm_arns
}

output "mfa_delete_enabled" {
  description = "Whether MFA delete is enabled."
  value       = module.s3_bucket.mfa_delete_enabled
}

output "replication_role_arn" {
  description = "Replication IAM role ARN (null when replication is disabled)."
  value       = module.s3_bucket.replication_role_arn
}
