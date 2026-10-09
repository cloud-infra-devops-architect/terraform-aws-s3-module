################################################################################
# Replication (Reliability) — same- or cross-region / cross-account
################################################################################

locals {
  create_replication_role = var.enable_replication && var.replication_role_arn == null
  replication_role_arn    = var.enable_replication ? coalesce(var.replication_role_arn, try(aws_iam_role.replication[0].arn, null)) : null

  vpce_exempt_principal_arns = concat(var.vpce_policy_exempt_principal_arns, compact([local.replication_role_arn]))
}

data "aws_iam_policy_document" "replication_assume" {
  count = local.create_replication_role ? 1 : 0

  statement {
    sid     = "AllowS3ToAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

data "aws_iam_policy_document" "replication" {
  count = local.create_replication_role ? 1 : 0

  statement {
    sid       = "SourceBucketConfiguration"
    effect    = "Allow"
    actions   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
    resources = [aws_s3_bucket.this.arn]
  }

  statement {
    sid    = "SourceObjectVersions"
    effect = "Allow"
    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
      "s3:GetObjectRetention",
      "s3:GetObjectLegalHold",
    ]
    resources = ["${aws_s3_bucket.this.arn}/*"]
  }

  statement {
    sid    = "DestinationReplicate"
    effect = "Allow"
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
      "s3:ObjectOwnerOverrideToBucketOwner",
    ]
    resources = ["${var.replication_destination_bucket_arn}/*"]
  }

  dynamic "statement" {
    for_each = local.use_kms ? [1] : []

    content {
      sid       = "DecryptSourceObjects"
      effect    = "Allow"
      actions   = ["kms:Decrypt"]
      resources = [local.kms_key_arn]

      condition {
        test     = "StringLike"
        variable = "kms:ViaService"
        values   = ["s3.${var.aws_region}.amazonaws.com"]
      }
    }
  }

  dynamic "statement" {
    for_each = var.replication_destination_kms_key_arn != null ? [1] : []

    content {
      sid       = "EncryptReplicaObjects"
      effect    = "Allow"
      actions   = ["kms:Encrypt", "kms:GenerateDataKey"]
      resources = [var.replication_destination_kms_key_arn]
    }
  }
}

resource "aws_iam_role" "replication" {
  count = local.create_replication_role ? 1 : 0

  name_prefix        = "s3-repl-"
  description        = "S3 replication role for bucket ${var.bucket_name}"
  assume_role_policy = data.aws_iam_policy_document.replication_assume[0].json

  tags = merge(local.common_tags, { Name = "${var.bucket_name}-replication" })
}

resource "aws_iam_role_policy" "replication" {
  count = local.create_replication_role ? 1 : 0

  name   = "s3-replication"
  role   = aws_iam_role.replication[0].id
  policy = data.aws_iam_policy_document.replication[0].json
}

resource "aws_s3_bucket_replication_configuration" "this" {
  count = var.enable_replication ? 1 : 0

  region = var.aws_region
  bucket = aws_s3_bucket.this.id
  role   = local.replication_role_arn

  rule {
    id     = "replicate-entire-bucket"
    status = "Enabled"

    filter {}

    delete_marker_replication {
      status = var.replication_replicate_delete_markers ? "Enabled" : "Disabled"
    }

    dynamic "source_selection_criteria" {
      for_each = local.use_kms ? [1] : []

      content {
        sse_kms_encrypted_objects {
          status = "Enabled"
        }
      }
    }

    destination {
      bucket        = var.replication_destination_bucket_arn
      storage_class = var.replication_storage_class
      account       = var.replication_destination_account_id

      dynamic "access_control_translation" {
        for_each = var.replication_destination_account_id != null ? [1] : []

        content {
          owner = "Destination"
        }
      }

      dynamic "encryption_configuration" {
        for_each = var.replication_destination_kms_key_arn != null ? [1] : []

        content {
          replica_kms_key_id = var.replication_destination_kms_key_arn
        }
      }

      # S3 Replication Time Control: 99.99% of objects replicated within 15 minutes (SLA).
      dynamic "replication_time" {
        for_each = var.replication_time_control ? [1] : []

        content {
          status = "Enabled"

          time {
            minutes = 15
          }
        }
      }

      dynamic "metrics" {
        for_each = var.replication_time_control ? [1] : []

        content {
          status = "Enabled"

          event_threshold {
            minutes = 15
          }
        }
      }
    }
  }

  # Replication requires versioning to be enabled first.
  depends_on = [aws_s3_bucket_versioning.this]
}
