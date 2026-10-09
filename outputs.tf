output "bucket_id" {
  description = "Name (ID) of the S3 bucket."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket."
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "Bucket domain name, in the format <bucket>.s3.amazonaws.com."
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Region-specific bucket domain name, e.g. for CloudFront origins: <bucket>.s3.<region>.amazonaws.com."
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "bucket_hosted_zone_id" {
  description = "Route 53 hosted zone ID for the bucket's region."
  value       = aws_s3_bucket.this.hosted_zone_id
}

output "bucket_region" {
  description = "AWS region in which the bucket was created."
  value       = aws_s3_bucket.this.region
}

output "storage_class" {
  description = "Target storage class objects transition to (STANDARD means no transition)."
  value       = var.storage_class
}

output "encryption_type" {
  description = "Default server-side encryption type applied to the bucket (SSE-S3, SSE-KMS or DSSE-KMS)."
  value       = var.encryption_type
}

output "sse_algorithm" {
  description = "S3 server-side encryption algorithm in effect (AES256, aws:kms or aws:kms:dsse)."
  value       = local.sse_algorithm
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for default encryption (module-created or supplied). Null for SSE-S3."
  value       = local.kms_key_arn
}

output "kms_key_alias" {
  description = "Alias of the module-created KMS key. Null when no key was created."
  value       = try(aws_kms_alias.this[0].name, null)
}

output "versioning_status" {
  description = "Versioning status of the bucket (Enabled or Suspended)."
  value       = aws_s3_bucket_versioning.this.versioning_configuration[0].status
}

output "public_access_block_enabled" {
  description = "Whether an S3 Block Public Access configuration is attached to the bucket."
  value       = var.enable_public_access_block
}

output "cors_enabled" {
  description = "Whether a CORS configuration is attached to the bucket."
  value       = var.enable_cors
}

output "bucket_policy_json" {
  description = "Bucket policy JSON applied to the bucket. Null when no policy was attached."
  value       = try(aws_s3_bucket_policy.this[0].policy, null)
}

output "tags" {
  description = "Tags applied to the bucket."
  value       = aws_s3_bucket.this.tags_all
}

output "mfa_delete_enabled" {
  description = "Whether MFA delete is enabled on the bucket's versioning configuration."
  value       = var.enable_mfa_delete
}

output "object_lock_enabled" {
  description = "Whether S3 Object Lock is enabled on the bucket."
  value       = aws_s3_bucket.this.object_lock_enabled
}

output "object_lock_default_retention" {
  description = "Default Object Lock retention ({mode, days, years}). Null when no default retention is configured."
  value = var.object_lock_default_retention_mode == null ? null : {
    mode  = var.object_lock_default_retention_mode
    days  = var.object_lock_default_retention_days
    years = var.object_lock_default_retention_years
  }
}

output "lifecycle_rule_ids" {
  description = "IDs of the lifecycle rules applied to the bucket."
  value       = [for r in local.lifecycle_rules : r.id]
}

output "replication_enabled" {
  description = "Whether replication is configured."
  value       = var.enable_replication
}

output "replication_role_arn" {
  description = "ARN of the IAM role used for replication (module-created or supplied). Null when replication is disabled."
  value       = local.replication_role_arn
}

output "eventbridge_notifications_enabled" {
  description = "Whether S3 events are sent to Amazon EventBridge."
  value       = var.enable_eventbridge_notifications
}

output "cloudwatch_alarm_arns" {
  description = "Map of alarm key (4xx-errors, 5xx-errors) to CloudWatch alarm ARN. Empty when alarms are disabled."
  value       = { for k, a in aws_cloudwatch_metric_alarm.errors : k => a.arn }
}

output "inventory_configuration_name" {
  description = "Name of the S3 Inventory configuration. Null when inventory is disabled."
  value       = try(aws_s3_bucket_inventory.this[0].name, null)
}

output "transfer_acceleration_endpoint" {
  description = "S3 Transfer Acceleration endpoint. Null when acceleration is disabled."
  value       = var.enable_transfer_acceleration ? "${aws_s3_bucket.this.id}.s3-accelerate.amazonaws.com" : null
}
