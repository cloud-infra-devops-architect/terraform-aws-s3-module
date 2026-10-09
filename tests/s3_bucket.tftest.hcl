# Offline unit tests: `terraform test` (no AWS credentials needed; the AWS provider is mocked).

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  bucket_name                = "unit-test-bucket-123"
  aws_region                 = "us-east-1"
  storage_class              = "STANDARD"
  enable_public_access_block = true
  encryption_type            = "SSE-S3"
  enable_cors                = false
  environment                = "dev"
  project                    = "unit-test"
  owner                      = "platform"
  email                      = "platform@example.com"
}

run "sse_s3_defaults" {
  command = plan

  assert {
    condition     = local.sse_algorithm == "AES256"
    error_message = "SSE-S3 must map to AES256."
  }

  assert {
    condition     = length(aws_kms_key.this) == 0
    error_message = "No KMS key should be created for SSE-S3."
  }

  assert {
    condition     = length(aws_s3_bucket_public_access_block.this) == 1
    error_message = "Public access block must be created when enabled."
  }

  assert {
    condition     = length(aws_s3_bucket_cors_configuration.this) == 0
    error_message = "CORS must not be configured when disabled."
  }

  assert {
    condition     = length(aws_s3_bucket_policy.this) == 1
    error_message = "TLS-enforcing bucket policy must be attached by default."
  }

  assert {
    condition     = aws_s3_bucket.this.region == "us-east-1"
    error_message = "Bucket must be created in var.aws_region."
  }
}

run "sse_kms_creates_cmk_and_transitions" {
  command = plan

  variables {
    encryption_type               = "SSE-KMS"
    storage_class                 = "STANDARD_IA"
    storage_class_transition_days = 30
    enable_cors                   = true
    cors_rules = [{
      allowed_methods = ["GET"]
      allowed_origins = ["https://app.example.com"]
    }]
  }

  assert {
    condition     = length(aws_kms_key.this) == 1 && aws_kms_key.this[0].enable_key_rotation
    error_message = "A rotating CMK must be created for SSE-KMS without kms_key_arn."
  }

  assert {
    condition     = local.sse_algorithm == "aws:kms"
    error_message = "SSE-KMS must map to aws:kms."
  }

  assert {
    condition     = length(aws_s3_bucket_cors_configuration.this) == 1
    error_message = "CORS must be configured when enabled."
  }

  assert {
    condition     = [for r in local.lifecycle_rules : r.id] == ["abort-incomplete-multipart-uploads", "transition-to-standard-ia", "expire-noncurrent-versions"]
    error_message = "Lifecycle must abort uploads, transition to STANDARD_IA and expire noncurrent versions."
  }
}

run "dsse_kms_with_existing_key" {
  command = plan

  variables {
    encryption_type = "DSSE-KMS"
    kms_key_arn     = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
  }

  assert {
    condition     = length(aws_kms_key.this) == 0 && local.kms_key_arn == var.kms_key_arn
    error_message = "Supplied kms_key_arn must be used without creating a key."
  }
}

run "public_access_block_disabled" {
  command = plan

  variables {
    enable_public_access_block = false
  }

  assert {
    condition     = length(aws_s3_bucket_public_access_block.this) == 0
    error_message = "Public access block must not be created when disabled."
  }
}

run "rejects_invalid_storage_class" {
  command = plan

  variables {
    storage_class = "REDUCED_REDUNDANCY"
  }

  expect_failures = [var.storage_class]
}

run "rejects_ia_transition_under_30_days" {
  command = plan

  variables {
    storage_class                 = "ONEZONE_IA"
    storage_class_transition_days = 10
  }

  expect_failures = [var.storage_class_transition_days]
}

run "rejects_cors_enabled_without_rules" {
  command = plan

  variables {
    enable_cors = true
  }

  expect_failures = [var.cors_rules]
}

run "rejects_invalid_bucket_name" {
  command = plan

  variables {
    bucket_name = "Invalid_Bucket"
  }

  expect_failures = [var.bucket_name]
}

run "rejects_kms_key_with_sse_s3" {
  command = plan

  variables {
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
  }

  expect_failures = [var.kms_key_arn]
}

run "rejects_invalid_region" {
  command = plan

  variables {
    aws_region = "us-east"
  }

  expect_failures = [var.aws_region]
}

# ── Well-Architected features ────────────────────────────────────────────────

run "secure_defaults_policy_and_events" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket_notification.this) == 1
    error_message = "EventBridge notifications must be on by default."
  }

  assert {
    condition     = length(aws_s3_bucket_metric.this) == 0 && length(aws_cloudwatch_metric_alarm.errors) == 0
    error_message = "Request metrics and alarms must be opt-in."
  }

  assert {
    condition     = aws_s3_bucket_versioning.this.mfa == null
    error_message = "No MFA token must be sent unless MFA delete is enabled."
  }
}

run "mfa_delete_enabled" {
  command = plan

  variables {
    enable_mfa_delete = true
    mfa               = "arn:aws:iam::123456789012:mfa/root-account-mfa-device 123456"
  }

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].mfa_delete == "Enabled"
    error_message = "MFA delete must be enabled on the versioning configuration."
  }
}

run "rejects_mfa_delete_without_token" {
  command = plan

  variables {
    enable_mfa_delete = true
  }

  expect_failures = [var.mfa]
}

run "rejects_mfa_delete_without_versioning" {
  command = plan

  variables {
    enable_mfa_delete = true
    enable_versioning = false
    mfa               = "arn:aws:iam::123456789012:mfa/root-account-mfa-device 123456"
  }

  expect_failures = [var.enable_mfa_delete]
}

run "object_lock_compliance_retention" {
  command = plan

  variables {
    object_lock_enabled                = true
    object_lock_default_retention_mode = "COMPLIANCE"
    object_lock_default_retention_days = 365
  }

  assert {
    condition     = aws_s3_bucket_object_lock_configuration.this[0].rule[0].default_retention[0].mode == "COMPLIANCE"
    error_message = "Object Lock default retention must be COMPLIANCE."
  }
}

run "rejects_object_lock_days_and_years" {
  command = plan

  variables {
    object_lock_enabled                 = true
    object_lock_default_retention_mode  = "GOVERNANCE"
    object_lock_default_retention_days  = 30
    object_lock_default_retention_years = 1
  }

  expect_failures = [var.object_lock_default_retention_days]
}

run "replication_with_kms_creates_role" {
  command = plan

  variables {
    encryption_type                     = "SSE-KMS"
    enable_replication                  = true
    replication_destination_bucket_arn  = "arn:aws:s3:::unit-test-replica"
    replication_destination_kms_key_arn = "arn:aws:kms:us-west-2:123456789012:key/11111111-2222-3333-4444-555555555555"
    replication_time_control            = true
  }

  assert {
    condition     = length(aws_iam_role.replication) == 1 && length(aws_s3_bucket_replication_configuration.this) == 1
    error_message = "Replication must create a role and a replication configuration."
  }

  assert {
    condition     = aws_s3_bucket_replication_configuration.this[0].rule[0].source_selection_criteria[0].sse_kms_encrypted_objects[0].status == "Enabled"
    error_message = "KMS-encrypted objects must be selected for replication."
  }
}

run "rejects_kms_replication_without_replica_key" {
  command = plan

  variables {
    encryption_type                    = "SSE-KMS"
    enable_replication                 = true
    replication_destination_bucket_arn = "arn:aws:s3:::unit-test-replica"
  }

  expect_failures = [var.replication_destination_kms_key_arn]
}

run "alarms_require_request_metrics" {
  command = plan

  variables {
    create_cloudwatch_alarms = true
  }

  expect_failures = [var.create_cloudwatch_alarms]
}

run "alarms_created_with_metrics" {
  command = plan

  variables {
    enable_request_metrics   = true
    create_cloudwatch_alarms = true
  }

  assert {
    condition     = toset(keys(aws_cloudwatch_metric_alarm.errors)) == toset(["4xx-errors", "5xx-errors"])
    error_message = "4xx and 5xx alarms must be created."
  }
}

run "noncurrent_transition_rule" {
  command = plan

  variables {
    noncurrent_version_transition_days = 30
  }

  assert {
    condition     = contains([for r in local.lifecycle_rules : r.id], "transition-noncurrent-versions")
    error_message = "Noncurrent versions must transition when configured."
  }
}

run "rejects_transfer_acceleration_with_dotted_name" {
  command = plan

  variables {
    bucket_name                  = "unit.test.bucket"
    enable_transfer_acceleration = true
  }

  expect_failures = [var.enable_transfer_acceleration]
}

run "rejects_invalid_vpce_id" {
  command = plan

  variables {
    allowed_vpc_endpoint_ids = ["endpoint-123"]
  }

  expect_failures = [var.allowed_vpc_endpoint_ids]
}
