################################################################################
# Observability (Operational Excellence)
################################################################################

resource "aws_s3_bucket_logging" "this" {
  count = var.enable_access_logging ? 1 : 0

  region        = var.aws_region
  bucket        = aws_s3_bucket.this.id
  target_bucket = var.logging_target_bucket
  target_prefix = var.logging_target_prefix

  # Date-partitioned keys make logs efficient to query with Athena.
  dynamic "target_object_key_format" {
    for_each = var.logging_partitioned_prefix ? [1] : []

    content {
      partitioned_prefix {
        partition_date_source = "EventTime"
      }
    }
  }
}

# Publishes all object-level events to Amazon EventBridge; route them with EventBridge rules
# instead of per-bucket SNS/SQS/Lambda wiring.
resource "aws_s3_bucket_notification" "this" {
  count = var.enable_eventbridge_notifications ? 1 : 0

  region      = var.aws_region
  bucket      = aws_s3_bucket.this.id
  eventbridge = true
}

# CloudWatch request metrics (1-minute) for the whole bucket; required for 4xx/5xx alarms.
resource "aws_s3_bucket_metric" "this" {
  count = var.enable_request_metrics ? 1 : 0

  region = var.aws_region
  bucket = aws_s3_bucket.this.id
  name   = local.request_metrics_filter_id
}

resource "aws_cloudwatch_metric_alarm" "errors" {
  for_each = var.create_cloudwatch_alarms ? local.alarms : {}

  region              = var.aws_region
  alarm_name          = "${var.bucket_name}-${each.key}"
  alarm_description   = each.value.description
  namespace           = "AWS/S3"
  metric_name         = each.value.metric_name
  statistic           = "Sum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_evaluation_periods
  threshold           = each.value.threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions

  dimensions = {
    BucketName = aws_s3_bucket.this.id
    FilterId   = local.request_metrics_filter_id
  }

  tags = merge(local.common_tags, { Name = "${var.bucket_name}-${each.key}" })

  depends_on = [aws_s3_bucket_metric.this]
}

resource "aws_s3_bucket_inventory" "this" {
  count = var.enable_inventory ? 1 : 0

  region                   = var.aws_region
  bucket                   = aws_s3_bucket.this.id
  name                     = "entire-bucket-${lower(var.inventory_frequency)}"
  included_object_versions = var.enable_versioning ? "All" : "Current"
  optional_fields          = var.inventory_optional_fields

  schedule {
    frequency = var.inventory_frequency
  }

  destination {
    bucket {
      format     = var.inventory_format
      bucket_arn = var.inventory_destination_bucket_arn
      prefix     = "s3-inventory/${var.bucket_name}"

      encryption {
        sse_s3 {}
      }
    }
  }
}
