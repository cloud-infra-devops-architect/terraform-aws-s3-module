################################################################################
# Locals
################################################################################

locals {
  common_tags = merge(
    var.tags,
    {
      Name        = var.bucket_name
      Environment = var.environment
      Project     = var.project
      Owner       = var.owner
      Email       = var.email
      ManagedBy   = "terraform"
    }
  )

  sse_algorithm = {
    "SSE-S3"   = "AES256"
    "SSE-KMS"  = "aws:kms"
    "DSSE-KMS" = "aws:kms:dsse"
  }[var.encryption_type]

  use_kms        = var.encryption_type != "SSE-S3"
  create_kms_key = local.use_kms && var.kms_key_arn == null
  kms_key_arn    = local.use_kms ? coalesce(var.kms_key_arn, try(aws_kms_key.this[0].arn, null)) : null

  transition_enabled = var.storage_class != "STANDARD"

  request_metrics_filter_id = "EntireBucket"

  alarms = {
    "5xx-errors" = {
      metric_name = "5xxErrors"
      threshold   = var.alarm_5xx_errors_threshold
      description = "S3 bucket ${var.bucket_name} is returning server-side (5xx) errors."
    }
    "4xx-errors" = {
      metric_name = "4xxErrors"
      threshold   = var.alarm_4xx_errors_threshold
      description = "S3 bucket ${var.bucket_name} is returning client-side (4xx) errors, e.g. AccessDenied."
    }
  }

  create_bucket_policy = anytrue([
    var.enforce_tls,
    var.deny_ssec_uploads,
    var.enforce_bucket_kms_key && local.use_kms,
    var.allowed_organization_id != null,
    length(var.allowed_vpc_endpoint_ids) > 0,
    var.additional_bucket_policy_json != null,
  ])

  # One object per lifecycle rule; null attributes are omitted from the rendered rule.
  lifecycle_rule_defaults = {
    abort_days                  = null
    transition_class            = null
    transition_days             = null
    noncurrent_transition_days  = null
    noncurrent_transition_class = null
    noncurrent_days             = null
    expiration_days             = null
    expire_delete_markers       = false
  }

  lifecycle_rules = concat(
    [merge(local.lifecycle_rule_defaults, {
      id         = "abort-incomplete-multipart-uploads"
      abort_days = var.abort_incomplete_multipart_upload_days
    })],
    local.transition_enabled ? [merge(local.lifecycle_rule_defaults, {
      id               = "transition-to-${lower(replace(var.storage_class, "_", "-"))}"
      transition_class = var.storage_class
      transition_days  = var.storage_class_transition_days
    })] : [],
    var.enable_versioning && var.noncurrent_version_transition_days != null ? [merge(local.lifecycle_rule_defaults, {
      id                          = "transition-noncurrent-versions"
      noncurrent_transition_days  = var.noncurrent_version_transition_days
      noncurrent_transition_class = var.noncurrent_version_transition_storage_class
    })] : [],
    var.enable_versioning && var.noncurrent_version_expiration_days != null ? [merge(local.lifecycle_rule_defaults, {
      id                    = "expire-noncurrent-versions"
      noncurrent_days       = var.noncurrent_version_expiration_days
      expire_delete_markers = true
    })] : [],
    var.object_expiration_days != null ? [merge(local.lifecycle_rule_defaults, {
      id              = "expire-current-objects"
      expiration_days = var.object_expiration_days
    })] : [],
  )
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

################################################################################
# S3 bucket
################################################################################

# Trivy ignores are justified in .trivyignore; Checkov skips are justified inline below.
resource "aws_s3_bucket" "this" {
  #checkov:skip=CKV_AWS_144:Cross-region replication is supported but optional (enable_replication); it needs a consumer-owned destination bucket.
  #checkov:skip=CKV2_AWS_62:Event notifications are supported but optional (enable_eventbridge_notifications).
  #checkov:skip=CKV_AWS_18:Server access logging is supported but optional (enable_access_logging); the target bucket is consumer-owned.
  #checkov:skip=CKV_AWS_145:SSE-S3 is an explicitly supported option (encryption_type); SSE-KMS/DSSE-KMS are available.
  region              = var.aws_region
  bucket              = var.bucket_name
  force_destroy       = var.force_destroy
  object_lock_enabled = var.object_lock_enabled

  tags = local.common_tags
}

resource "aws_s3_bucket_ownership_controls" "this" {
  region = var.aws_region
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = var.object_ownership
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  count = var.enable_public_access_block ? 1 : 0

  region                  = var.aws_region
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}

# MFA delete can only be enabled by the root user with its MFA device. S3 requires the
# x-amz-mfa header whenever MfaDelete is sent, so it is omitted (null) unless enabled.
resource "aws_s3_bucket_versioning" "this" {
  region = var.aws_region
  bucket = aws_s3_bucket.this.id
  mfa    = var.enable_mfa_delete ? var.mfa : null

  versioning_configuration {
    status     = var.enable_versioning ? "Enabled" : "Suspended"
    mfa_delete = var.enable_mfa_delete ? "Enabled" : null
  }
}

resource "aws_s3_bucket_object_lock_configuration" "this" {
  count = var.object_lock_enabled && var.object_lock_default_retention_mode != null ? 1 : 0

  region = var.aws_region
  bucket = aws_s3_bucket.this.id

  rule {
    default_retention {
      mode  = var.object_lock_default_retention_mode
      days  = var.object_lock_default_retention_days
      years = var.object_lock_default_retention_years
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  region = var.aws_region
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.sse_algorithm
      kms_master_key_id = local.kms_key_arn
    }
    # Bucket Keys are only supported for SSE-KMS.
    bucket_key_enabled = var.encryption_type == "SSE-KMS" ? var.bucket_key_enabled : null
  }
}

resource "aws_s3_bucket_cors_configuration" "this" {
  count = var.enable_cors ? 1 : 0

  region = var.aws_region
  bucket = aws_s3_bucket.this.id

  dynamic "cors_rule" {
    for_each = var.cors_rules

    content {
      id              = cors_rule.value.id
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      allowed_headers = cors_rule.value.allowed_headers
      expose_headers  = cors_rule.value.expose_headers
      max_age_seconds = cors_rule.value.max_age_seconds
    }
  }
}

################################################################################
# Performance Efficiency & Cost
################################################################################

resource "aws_s3_bucket_accelerate_configuration" "this" {
  count = var.enable_transfer_acceleration ? 1 : 0

  region = var.aws_region
  bucket = aws_s3_bucket.this.id
  status = "Enabled"
}

resource "aws_s3_bucket_request_payment_configuration" "this" {
  count = var.enable_requester_pays ? 1 : 0

  region = var.aws_region
  bucket = aws_s3_bucket.this.id
  payer  = "Requester"
}
