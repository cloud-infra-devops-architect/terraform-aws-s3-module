# Defaults are provided so `terraform plan` can run in CI without a tfvars file.
# Validation is enforced by the module; these variables only pass values through.

variable "bucket_name" {
  description = "Globally unique name of the S3 bucket."
  type        = string
  default     = "evolv-example-s3-module-dev-bucket"
}

variable "aws_region" {
  description = "AWS region for the provider and the bucket."
  type        = string
  default     = "us-east-1"
}

variable "storage_class" {
  description = "Target storage class: STANDARD, INTELLIGENT_TIERING, STANDARD_IA, ONEZONE_IA, GLACIER_IR, GLACIER or DEEP_ARCHIVE."
  type        = string
  default     = "INTELLIGENT_TIERING"
}

variable "storage_class_transition_days" {
  description = "Days after creation before objects transition to storage_class."
  type        = number
  default     = 0
}

variable "enable_public_access_block" {
  description = "Whether to attach S3 Block Public Access to the bucket."
  type        = bool
  default     = true
}

variable "encryption_type" {
  description = "Default encryption: SSE-S3, SSE-KMS or DSSE-KMS."
  type        = string
  default     = "SSE-KMS"
}

variable "kms_key_arn" {
  description = "Existing KMS key ARN for SSE-KMS/DSSE-KMS. Null lets the module create one."
  type        = string
  default     = null
}

variable "enable_cors" {
  description = "Whether to apply a CORS configuration."
  type        = bool
  default     = true
}

variable "cors_rules" {
  description = "CORS rules applied when enable_cors is true."
  type = list(object({
    id              = optional(string)
    allowed_methods = list(string)
    allowed_origins = list(string)
    allowed_headers = optional(list(string), [])
    expose_headers  = optional(list(string), [])
    max_age_seconds = optional(number, 3000)
  }))
  default = [
    {
      id              = "web-app-read"
      allowed_methods = ["GET", "HEAD"]
      allowed_origins = ["https://app.example.com"]
      allowed_headers = ["Authorization", "Content-Type"]
      expose_headers  = ["ETag"]
      max_age_seconds = 3000
    }
  ]
}

variable "enable_versioning" {
  description = "Enable object versioning."
  type        = bool
  default     = true
}

variable "enable_access_logging" {
  description = "Enable server access logging to logging_target_bucket."
  type        = bool
  default     = false
}

variable "logging_target_bucket" {
  description = "Existing bucket that receives server access logs (required when enable_access_logging is true)."
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Allow destroying the bucket while it still contains objects."
  type        = bool
  default     = false
}

variable "environment" {
  description = "Deployment environment tag (dev, qa, uat, stage, prod, sandbox)."
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Project tag."
  type        = string
  default     = "terraform-aws-s3-module"
}

variable "owner" {
  description = "Owner tag."
  type        = string
  default     = "platform-engineering"
}

variable "email" {
  description = "Owner contact email tag."
  type        = string
  default     = "platform-engineering@example.com"
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default = {
    CostCenter = "cloud-platform"
  }
}

variable "enable_mfa_delete" {
  description = "Enable MFA delete (root user only; also set mfa)."
  type        = bool
  default     = false
}

variable "mfa" {
  description = "Root MFA serial/ARN and current code (\"<serial> <code>\"); pass via TF_VAR_mfa at apply time."
  type        = string
  default     = null
  sensitive   = true
}

variable "object_lock_enabled" {
  description = "Enable S3 Object Lock (only at bucket creation)."
  type        = bool
  default     = false
}

variable "object_lock_default_retention_mode" {
  description = "Default Object Lock retention mode: GOVERNANCE, COMPLIANCE or null."
  type        = string
  default     = null
}

variable "object_lock_default_retention_days" {
  description = "Default Object Lock retention in days."
  type        = number
  default     = null
}

variable "allowed_organization_id" {
  description = "AWS Organizations ID allowed to access the bucket (null = no org restriction)."
  type        = string
  default     = null
}

variable "enable_replication" {
  description = "Enable replication to replication_destination_bucket_arn."
  type        = bool
  default     = false
}

variable "replication_destination_bucket_arn" {
  description = "Destination bucket ARN for replication."
  type        = string
  default     = null
}

variable "replication_destination_kms_key_arn" {
  description = "Destination-region KMS key ARN for replicas (required for SSE-KMS sources)."
  type        = string
  default     = null
}

variable "noncurrent_version_transition_days" {
  description = "Days before noncurrent versions move to GLACIER_IR (null disables)."
  type        = number
  default     = 30
}

variable "enable_request_metrics" {
  description = "Enable CloudWatch request metrics and 4xx/5xx alarms."
  type        = bool
  default     = true
}

variable "alarm_actions" {
  description = "SNS topic ARNs notified by the CloudWatch alarms."
  type        = list(string)
  default     = []
}
