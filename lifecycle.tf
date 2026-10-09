################################################################################
# Lifecycle & storage class (Cost Optimization / Sustainability)
################################################################################

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  region = var.aws_region
  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = local.lifecycle_rules

    content {
      id     = rule.value.id
      status = "Enabled"

      filter {}

      dynamic "abort_incomplete_multipart_upload" {
        for_each = rule.value.abort_days != null ? [rule.value.abort_days] : []

        content {
          days_after_initiation = abort_incomplete_multipart_upload.value
        }
      }

      dynamic "transition" {
        for_each = rule.value.transition_class != null ? [rule.value] : []

        content {
          days          = transition.value.transition_days
          storage_class = transition.value.transition_class
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = rule.value.noncurrent_transition_days != null ? [rule.value] : []

        content {
          noncurrent_days = noncurrent_version_transition.value.noncurrent_transition_days
          storage_class   = noncurrent_version_transition.value.noncurrent_transition_class
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_days != null ? [rule.value.noncurrent_days] : []

        content {
          noncurrent_days = noncurrent_version_expiration.value
        }
      }

      dynamic "expiration" {
        for_each = rule.value.expire_delete_markers || rule.value.expiration_days != null ? [rule.value] : []

        content {
          days                         = expiration.value.expiration_days
          expired_object_delete_marker = expiration.value.expire_delete_markers ? true : null
        }
      }
    }
  }

  # Lifecycle rules referencing versions must be applied after versioning is configured.
  depends_on = [aws_s3_bucket_versioning.this]
}

resource "aws_s3_bucket_intelligent_tiering_configuration" "this" {
  count = var.storage_class == "INTELLIGENT_TIERING" && var.enable_intelligent_tiering_archive ? 1 : 0

  region = var.aws_region
  bucket = aws_s3_bucket.this.id
  name   = "entire-bucket-archive"
  status = "Enabled"

  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = var.intelligent_tiering_archive_days
  }

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = var.intelligent_tiering_deep_archive_days
  }
}
