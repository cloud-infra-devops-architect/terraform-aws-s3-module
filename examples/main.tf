terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Repository = "terraform-aws-s3-module"
    }
  }
}

module "s3_bucket" {
  source = "../"

  # Required inputs
  bucket_name                = var.bucket_name
  aws_region                 = var.aws_region
  storage_class              = var.storage_class
  enable_public_access_block = var.enable_public_access_block
  encryption_type            = var.encryption_type
  enable_cors                = var.enable_cors

  environment = var.environment
  project     = var.project
  owner       = var.owner
  email       = var.email

  # Optional inputs
  storage_class_transition_days = var.storage_class_transition_days
  kms_key_arn                   = var.kms_key_arn
  cors_rules                    = var.cors_rules
  enable_versioning             = var.enable_versioning
  enable_access_logging         = var.enable_access_logging
  logging_target_bucket         = var.logging_target_bucket
  force_destroy                 = var.force_destroy

  # Well-Architected: Security / Reliability
  enable_mfa_delete                   = var.enable_mfa_delete
  mfa                                 = var.mfa
  object_lock_enabled                 = var.object_lock_enabled
  object_lock_default_retention_mode  = var.object_lock_default_retention_mode
  object_lock_default_retention_days  = var.object_lock_default_retention_days
  deny_ssec_uploads                   = true
  enforce_bucket_kms_key              = true
  allowed_organization_id             = var.allowed_organization_id
  enable_replication                  = var.enable_replication
  replication_destination_bucket_arn  = var.replication_destination_bucket_arn
  replication_destination_kms_key_arn = var.replication_destination_kms_key_arn

  # Well-Architected: Cost Optimization
  noncurrent_version_transition_days          = var.noncurrent_version_transition_days
  noncurrent_version_transition_storage_class = "GLACIER_IR"
  noncurrent_version_expiration_days          = 365

  # Well-Architected: Operational Excellence
  enable_eventbridge_notifications = true
  enable_request_metrics           = var.enable_request_metrics
  create_cloudwatch_alarms         = var.enable_request_metrics
  alarm_actions                    = var.alarm_actions

  tags = var.tags
}
