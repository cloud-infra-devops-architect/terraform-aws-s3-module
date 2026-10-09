################################################################################
# KMS customer managed key (only when SSE-KMS/DSSE-KMS without kms_key_arn)
################################################################################

data "aws_iam_policy_document" "kms" {
  #checkov:skip=CKV_AWS_109:KMS key policies must use Resource "*" (it refers only to this key); root access mirrors the AWS default key policy.
  #checkov:skip=CKV_AWS_111:KMS key policies must use Resource "*" (it refers only to this key); root access mirrors the AWS default key policy.
  #checkov:skip=CKV_AWS_356:KMS key policies must use Resource "*" (it refers only to this key).
  count = local.create_kms_key ? 1 : 0

  statement {
    sid       = "EnableRootAccountPermissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  dynamic "statement" {
    for_each = length(var.kms_key_administrator_arns) > 0 ? [1] : []

    content {
      sid    = "AllowKeyAdministration"
      effect = "Allow"
      actions = [
        "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*", "kms:Put*",
        "kms:Update*", "kms:Revoke*", "kms:Disable*", "kms:Get*", "kms:Delete*",
        "kms:TagResource", "kms:UntagResource", "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion",
      ]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = var.kms_key_administrator_arns
      }
    }
  }
}

resource "aws_kms_key" "this" {
  count = local.create_kms_key ? 1 : 0

  region                  = var.aws_region
  description             = "CMK for default encryption of S3 bucket ${var.bucket_name}"
  key_usage               = "ENCRYPT_DECRYPT"
  deletion_window_in_days = var.kms_key_deletion_window_in_days
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms[0].json

  tags = merge(local.common_tags, { Name = "${var.bucket_name}-kms" })
}

resource "aws_kms_alias" "this" {
  count = local.create_kms_key ? 1 : 0

  region        = var.aws_region
  name          = "alias/s3/${replace(var.bucket_name, ".", "-")}"
  target_key_id = aws_kms_key.this[0].key_id
}
