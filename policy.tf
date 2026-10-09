################################################################################
# Bucket policy (Security pillar: TLS, SSE-C block, KMS key, org & VPC endpoint perimeter)
################################################################################

data "aws_iam_policy_document" "bucket" {
  count = local.create_bucket_policy ? 1 : 0

  source_policy_documents = var.additional_bucket_policy_json != null ? [var.additional_bucket_policy_json] : []

  dynamic "statement" {
    for_each = var.enforce_tls ? [1] : []

    content {
      sid       = "DenyInsecureTransport"
      effect    = "Deny"
      actions   = ["s3:*"]
      resources = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"]

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      condition {
        test     = "Bool"
        variable = "aws:SecureTransport"
        values   = ["false"]
      }
    }
  }

  dynamic "statement" {
    for_each = var.enforce_tls ? [1] : []

    content {
      sid       = "DenyOutdatedTLS"
      effect    = "Deny"
      actions   = ["s3:*"]
      resources = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"]

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      condition {
        test     = "NumericLessThan"
        variable = "s3:TlsVersion"
        values   = [var.minimum_tls_version]
      }
    }
  }
  # Block SSE-C: customer-provided keys bypass KMS auditing and key-policy controls.
  dynamic "statement" {
    for_each = var.deny_ssec_uploads ? [1] : []

    content {
      sid       = "DenySSECUploads"
      effect    = "Deny"
      actions   = ["s3:PutObject"]
      resources = ["${aws_s3_bucket.this.arn}/*"]

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      condition {
        test     = "Null"
        variable = "s3:x-amz-server-side-encryption-customer-algorithm"
        values   = ["false"]
      }
    }
  }

  # Uploads that name a KMS key must use the bucket's key (requests without the header
  # fall back to default encryption and are allowed).
  dynamic "statement" {
    for_each = var.enforce_bucket_kms_key && local.use_kms ? [1] : []

    content {
      sid       = "DenyIncorrectKmsKey"
      effect    = "Deny"
      actions   = ["s3:PutObject"]
      resources = ["${aws_s3_bucket.this.arn}/*"]

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      condition {
        test     = "StringNotEqualsIfExists"
        variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
        values   = [local.kms_key_arn]
      }
    }
  }

  # Data perimeter: only principals from the AWS Organization (AWS services exempt).
  dynamic "statement" {
    for_each = var.allowed_organization_id != null ? [1] : []

    content {
      sid       = "DenyOutsideOrganization"
      effect    = "Deny"
      actions   = ["s3:*"]
      resources = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"]

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      condition {
        test     = "StringNotEquals"
        variable = "aws:PrincipalOrgID"
        values   = [var.allowed_organization_id]
      }

      condition {
        test     = "BoolIfExists"
        variable = "aws:PrincipalIsAWSService"
        values   = ["false"]
      }
    }
  }

  # Network perimeter: only requests through the listed VPC endpoints, except exempt principals.
  dynamic "statement" {
    for_each = length(var.allowed_vpc_endpoint_ids) > 0 ? [1] : []

    content {
      sid       = "DenyOutsideVpcEndpoints"
      effect    = "Deny"
      actions   = ["s3:*"]
      resources = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"]

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      condition {
        test     = "StringNotEquals"
        variable = "aws:SourceVpce"
        values   = var.allowed_vpc_endpoint_ids
      }

      condition {
        test     = "BoolIfExists"
        variable = "aws:PrincipalIsAWSService"
        values   = ["false"]
      }

      # The replication role does not use a VPC endpoint, so it is always exempt.
      dynamic "condition" {
        for_each = length(local.vpce_exempt_principal_arns) > 0 ? [1] : []

        content {
          test     = "ArnNotLike"
          variable = "aws:PrincipalArn"
          values   = local.vpce_exempt_principal_arns
        }
      }
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  count = local.create_bucket_policy ? 1 : 0

  region = var.aws_region
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.bucket[0].json

  # Apply Block Public Access first so a permissive caller policy is rejected rather than applied.
  depends_on = [aws_s3_bucket_public_access_block.this]
}
