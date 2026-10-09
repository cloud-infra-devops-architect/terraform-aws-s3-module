################################################################################
# Required inputs
################################################################################

variable "bucket_name" {
  description = "Globally unique name of the S3 bucket. Must be 3-63 characters, lowercase letters, numbers, hyphens and dots only, and must start and end with a letter or number."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be 3-63 characters long, contain only lowercase letters, numbers, dots (.) and hyphens (-), and start and end with a letter or number."
  }

  validation {
    condition     = !can(regex("\\.\\.|\\.-|-\\.", var.bucket_name))
    error_message = "bucket_name must not contain two adjacent periods, or a period adjacent to a hyphen."
  }

  validation {
    condition     = !can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$", var.bucket_name))
    error_message = "bucket_name must not be formatted as an IP address (e.g. 192.168.5.4)."
  }

  validation {
    condition = !anytrue([
      startswith(var.bucket_name, "xn--"),
      startswith(var.bucket_name, "sthree-"),
      startswith(var.bucket_name, "amzn-s3-demo-"),
      endswith(var.bucket_name, "-s3alias"),
      endswith(var.bucket_name, "--ol-s3"),
      endswith(var.bucket_name, ".mrap"),
      endswith(var.bucket_name, "--x-s3"),
      endswith(var.bucket_name, "--table-s3"),
    ])
    error_message = "bucket_name must not use an AWS reserved prefix (xn--, sthree-, amzn-s3-demo-) or suffix (-s3alias, --ol-s3, .mrap, --x-s3, --table-s3)."
  }
}

variable "aws_region" {
  description = "AWS region in which the S3 bucket and all related resources (including the optional KMS key) are created, e.g. us-east-1. Passed to the resource-level `region` argument (AWS provider >= 6.0)."
  type        = string

  validation {
    condition     = can(regex("^(us|eu|ap|sa|ca|me|af|il|mx)(-gov)?-(north|south|east|west|central|northeast|northwest|southeast|southwest)-[1-9]$", var.aws_region))
    error_message = "aws_region must be a valid AWS region code, e.g. us-east-1, eu-west-2, ap-southeast-1, us-gov-west-1."
  }
}

variable "storage_class" {
  description = "Target S3 storage class for objects in the bucket. STANDARD keeps objects in S3 Standard; any other value adds a lifecycle transition that moves objects to that class after `storage_class_transition_days`. Allowed: STANDARD, INTELLIGENT_TIERING, STANDARD_IA, ONEZONE_IA, GLACIER_IR, GLACIER, DEEP_ARCHIVE."
  type        = string

  validation {
    condition     = contains(["STANDARD", "INTELLIGENT_TIERING", "STANDARD_IA", "ONEZONE_IA", "GLACIER_IR", "GLACIER", "DEEP_ARCHIVE"], var.storage_class)
    error_message = "storage_class must be one of: STANDARD, INTELLIGENT_TIERING, STANDARD_IA, ONEZONE_IA, GLACIER_IR, GLACIER, DEEP_ARCHIVE."
  }
}

variable "enable_public_access_block" {
  description = "Whether to attach an S3 Block Public Access configuration to the bucket. Strongly recommended to be true for all buckets that are not intentionally public."
  type        = bool
}

variable "encryption_type" {
  description = "Default server-side encryption for the bucket. SSE-S3 uses S3-managed keys (AES256); SSE-KMS uses an AWS KMS key (aws:kms); DSSE-KMS uses dual-layer KMS encryption (aws:kms:dsse). For the KMS options, supply `kms_key_arn` or a customer managed key is created by the module."
  type        = string

  validation {
    condition     = contains(["SSE-S3", "SSE-KMS", "DSSE-KMS"], var.encryption_type)
    error_message = "encryption_type must be one of: SSE-S3, SSE-KMS, DSSE-KMS."
  }
}

variable "enable_cors" {
  description = "Whether to apply a CORS configuration to the bucket. When true, at least one rule must be supplied in `cors_rules`."
  type        = bool
}

################################################################################
# Tagging inputs
################################################################################

variable "environment" {
  description = "Deployment environment used for tagging, e.g. dev, qa, uat, prod."
  type        = string

  validation {
    condition     = contains(["dev", "qa", "uat", "stage", "prod", "sandbox"], var.environment)
    error_message = "environment must be one of: dev, qa, uat, stage, prod, sandbox."
  }
}

variable "project" {
  description = "Project or application name used for tagging."
  type        = string

  validation {
    condition     = length(trimspace(var.project)) > 0 && length(var.project) <= 64
    error_message = "project must be a non-empty string of at most 64 characters."
  }
}

variable "owner" {
  description = "Team or individual that owns the bucket, used for tagging."
  type        = string

  validation {
    condition     = length(trimspace(var.owner)) > 0 && length(var.owner) <= 64
    error_message = "owner must be a non-empty string of at most 64 characters."
  }
}

variable "email" {
  description = "Contact email address of the owning team, used for tagging."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.email))
    error_message = "email must be a valid email address, e.g. team@example.com."
  }
}

variable "tags" {
  description = "Additional tags to apply to all taggable resources. Merged with (and overridden by) the mandatory Name, Environment, Project, Owner, Email and ManagedBy tags."
  type        = map(string)
  default     = {}

  validation {
    condition     = length(var.tags) <= 40
    error_message = "tags must contain at most 40 entries; S3 allows 50 tags per bucket and the module reserves the rest."
  }

  validation {
    condition = alltrue([
      for k, v in var.tags : length(k) >= 1 && length(k) <= 128 && length(v) <= 256 && !startswith(lower(k), "aws:")
    ])
    error_message = "Each tag key must be 1-128 characters and must not start with 'aws:'; each tag value must be at most 256 characters."
  }
}

################################################################################
# Storage class / lifecycle
################################################################################

variable "storage_class_transition_days" {
  description = "Number of days after object creation before objects transition to `storage_class`. Ignored when storage_class is STANDARD. STANDARD_IA and ONEZONE_IA require at least 30 days."
  type        = number
  default     = 30

  validation {
    condition     = var.storage_class_transition_days >= 0 && var.storage_class_transition_days <= 3650 && floor(var.storage_class_transition_days) == var.storage_class_transition_days
    error_message = "storage_class_transition_days must be a whole number between 0 and 3650."
  }

  validation {
    condition     = !contains(["STANDARD_IA", "ONEZONE_IA"], var.storage_class) || var.storage_class_transition_days >= 30
    error_message = "storage_class_transition_days must be at least 30 when storage_class is STANDARD_IA or ONEZONE_IA (S3 minimum)."
  }
}

variable "enable_intelligent_tiering_archive" {
  description = "When storage_class is INTELLIGENT_TIERING, also enable the opt-in Archive Access and Deep Archive Access tiers."
  type        = bool
  default     = false
}

variable "intelligent_tiering_archive_days" {
  description = "Days without access before objects move to the Intelligent-Tiering Archive Access tier (90-730)."
  type        = number
  default     = 90

  validation {
    condition     = var.intelligent_tiering_archive_days >= 90 && var.intelligent_tiering_archive_days <= 730
    error_message = "intelligent_tiering_archive_days must be between 90 and 730."
  }
}

variable "intelligent_tiering_deep_archive_days" {
  description = "Days without access before objects move to the Intelligent-Tiering Deep Archive Access tier (180-730). Must be greater than intelligent_tiering_archive_days."
  type        = number
  default     = 180

  validation {
    condition     = var.intelligent_tiering_deep_archive_days >= 180 && var.intelligent_tiering_deep_archive_days <= 730
    error_message = "intelligent_tiering_deep_archive_days must be between 180 and 730."
  }

  validation {
    condition     = var.intelligent_tiering_deep_archive_days > var.intelligent_tiering_archive_days
    error_message = "intelligent_tiering_deep_archive_days must be greater than intelligent_tiering_archive_days."
  }
}

variable "abort_incomplete_multipart_upload_days" {
  description = "Number of days after initiation to abort incomplete multipart uploads, removing their orphaned parts."
  type        = number
  default     = 7

  validation {
    condition     = var.abort_incomplete_multipart_upload_days >= 1 && var.abort_incomplete_multipart_upload_days <= 365
    error_message = "abort_incomplete_multipart_upload_days must be between 1 and 365."
  }
}

variable "noncurrent_version_expiration_days" {
  description = "Number of days after an object version becomes noncurrent before it is permanently deleted. Only applied when versioning is enabled. Set to null to keep noncurrent versions indefinitely."
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_version_expiration_days == null || try(var.noncurrent_version_expiration_days >= 1 && var.noncurrent_version_expiration_days <= 3650, false)
    error_message = "noncurrent_version_expiration_days must be null or between 1 and 3650."
  }
}

variable "object_expiration_days" {
  description = "Optional number of days after creation to expire current objects. Null (default) disables expiration. Must be greater than storage_class_transition_days when a transition is configured."
  type        = number
  default     = null

  validation {
    condition     = var.object_expiration_days == null || try(var.object_expiration_days >= 1 && var.object_expiration_days <= 36500, false)
    error_message = "object_expiration_days must be null or between 1 and 36500."
  }

  validation {
    condition     = var.object_expiration_days == null || var.storage_class == "STANDARD" || try(var.object_expiration_days > var.storage_class_transition_days, false)
    error_message = "object_expiration_days must be greater than storage_class_transition_days when storage_class is not STANDARD."
  }
}

################################################################################
# Public access block
################################################################################

variable "block_public_acls" {
  description = "Reject PUT requests that include public ACLs. Applies only when enable_public_access_block is true."
  type        = bool
  default     = true
}

variable "block_public_policy" {
  description = "Reject bucket policies that grant public access. Applies only when enable_public_access_block is true."
  type        = bool
  default     = true
}

variable "ignore_public_acls" {
  description = "Ignore all public ACLs on the bucket and its objects. Applies only when enable_public_access_block is true."
  type        = bool
  default     = true
}

variable "restrict_public_buckets" {
  description = "Restrict access to a bucket with a public policy to AWS service principals and authorized users in the owning account. Applies only when enable_public_access_block is true."
  type        = bool
  default     = true
}

################################################################################
# Encryption
################################################################################

variable "kms_key_arn" {
  description = "ARN of an existing KMS key used when encryption_type is SSE-KMS or DSSE-KMS. Leave null to have the module create a customer managed key with rotation enabled."
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_arn == null || can(regex("^arn:aws[a-zA-Z-]*:kms:[a-z0-9-]+:[0-9]{12}:(key|alias)/.+$", var.kms_key_arn))
    error_message = "kms_key_arn must be null or a valid KMS key/alias ARN, e.g. arn:aws:kms:us-east-1:123456789012:key/<key-id>."
  }

  validation {
    condition     = var.kms_key_arn == null || var.encryption_type != "SSE-S3"
    error_message = "kms_key_arn must not be set when encryption_type is SSE-S3."
  }
}

variable "kms_key_deletion_window_in_days" {
  description = "Waiting period (7-30 days) before a module-created KMS key is deleted after destroy."
  type        = number
  default     = 30

  validation {
    condition     = var.kms_key_deletion_window_in_days >= 7 && var.kms_key_deletion_window_in_days <= 30
    error_message = "kms_key_deletion_window_in_days must be between 7 and 30."
  }
}

variable "kms_key_administrator_arns" {
  description = "Optional IAM principal ARNs granted administrative (non-cryptographic) permissions on the module-created KMS key. The account root is always granted full access."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for arn in var.kms_key_administrator_arns : can(regex("^arn:aws[a-zA-Z-]*:iam::[0-9]{12}:(role|user)/.+$", arn))])
    error_message = "Each kms_key_administrator_arns entry must be a valid IAM role or user ARN."
  }
}

variable "bucket_key_enabled" {
  description = "Enable S3 Bucket Keys to reduce KMS request costs. Applies to SSE-KMS only (not supported for DSSE-KMS)."
  type        = bool
  default     = true
}

################################################################################
# CORS
################################################################################

variable "cors_rules" {
  description = "List of CORS rules applied when enable_cors is true. Each rule requires allowed_methods and allowed_origins; allowed_headers, expose_headers, max_age_seconds and id are optional."
  type = list(object({
    id              = optional(string)
    allowed_methods = list(string)
    allowed_origins = list(string)
    allowed_headers = optional(list(string), [])
    expose_headers  = optional(list(string), [])
    max_age_seconds = optional(number, 3000)
  }))
  default = []

  validation {
    condition     = length(var.cors_rules) <= 100
    error_message = "cors_rules supports at most 100 rules (S3 limit)."
  }

  validation {
    condition = alltrue(flatten([
      for rule in var.cors_rules : [
        for m in rule.allowed_methods : contains(["GET", "PUT", "POST", "DELETE", "HEAD"], m)
      ]
    ]))
    error_message = "cors_rules[*].allowed_methods may only contain GET, PUT, POST, DELETE or HEAD."
  }

  validation {
    condition     = alltrue([for rule in var.cors_rules : length(rule.allowed_methods) > 0 && length(rule.allowed_origins) > 0])
    error_message = "Each CORS rule must define at least one allowed_method and one allowed_origin."
  }

  validation {
    condition = alltrue(flatten([
      for rule in var.cors_rules : [
        for o in rule.allowed_origins : o == "*" || can(regex("^https?://[^\\s/]+$", o))
      ]
    ]))
    error_message = "cors_rules[*].allowed_origins entries must be \"*\" or an origin such as https://app.example.com (scheme + host, optional single * wildcard, no path)."
  }

  validation {
    condition     = alltrue([for rule in var.cors_rules : rule.max_age_seconds == null || try(rule.max_age_seconds >= 0 && rule.max_age_seconds <= 86400, false)])
    error_message = "cors_rules[*].max_age_seconds must be between 0 and 86400."
  }

  validation {
    condition     = alltrue([for rule in var.cors_rules : rule.id == null || try(length(rule.id) <= 255, false)])
    error_message = "cors_rules[*].id must be at most 255 characters."
  }

  validation {
    condition     = !var.enable_cors || length(var.cors_rules) > 0
    error_message = "cors_rules must contain at least one rule when enable_cors is true."
  }
}

################################################################################
# Bucket configuration
################################################################################

variable "enable_versioning" {
  description = "Enable S3 object versioning to protect against accidental overwrites and deletes."
  type        = bool
  default     = true
}

variable "object_ownership" {
  description = "Object ownership setting. BucketOwnerEnforced (recommended) disables ACLs; BucketOwnerPreferred and ObjectWriter keep ACLs enabled."
  type        = string
  default     = "BucketOwnerEnforced"

  validation {
    condition     = contains(["BucketOwnerEnforced", "BucketOwnerPreferred", "ObjectWriter"], var.object_ownership)
    error_message = "object_ownership must be one of: BucketOwnerEnforced, BucketOwnerPreferred, ObjectWriter."
  }
}

variable "force_destroy" {
  description = "Allow the bucket to be destroyed even when it contains objects. Objects are deleted irrecoverably; keep false outside of ephemeral environments."
  type        = bool
  default     = false
}

variable "object_lock_enabled" {
  description = "Enable S3 Object Lock on the bucket (WORM). Can only be set at bucket creation and requires versioning."
  type        = bool
  default     = false

  validation {
    condition     = !var.object_lock_enabled || var.enable_versioning
    error_message = "enable_versioning must be true when object_lock_enabled is true."
  }
}

variable "enforce_tls" {
  description = "Attach a bucket policy statement that denies any request not sent over HTTPS, or sent with TLS older than `minimum_tls_version`."
  type        = bool
  default     = true
}

variable "minimum_tls_version" {
  description = "Minimum TLS version accepted when enforce_tls is true."
  type        = string
  default     = "1.2"

  validation {
    condition     = contains(["1.2", "1.3"], var.minimum_tls_version)
    error_message = "minimum_tls_version must be 1.2 or 1.3."
  }
}

variable "additional_bucket_policy_json" {
  description = "Optional JSON IAM policy document merged into the bucket policy (e.g. from a data.aws_iam_policy_document). Statement Sids must not collide with DenyInsecureTransport or DenyOutdatedTLS."
  type        = string
  default     = null

  validation {
    condition     = var.additional_bucket_policy_json == null || can(jsondecode(var.additional_bucket_policy_json))
    error_message = "additional_bucket_policy_json must be null or a valid JSON document."
  }
}

################################################################################
# Server access logging
################################################################################

variable "enable_access_logging" {
  description = "Enable S3 server access logging to `logging_target_bucket`."
  type        = bool
  default     = false
}

variable "logging_target_bucket" {
  description = "Name of an existing bucket (in the same region and account) that receives server access logs. Required when enable_access_logging is true."
  type        = string
  default     = null

  validation {
    condition     = var.logging_target_bucket == null || can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.logging_target_bucket))
    error_message = "logging_target_bucket must be null or a valid S3 bucket name."
  }

  validation {
    condition     = !var.enable_access_logging || var.logging_target_bucket != null
    error_message = "logging_target_bucket is required when enable_access_logging is true."
  }

  validation {
    condition     = var.logging_target_bucket == null || var.logging_target_bucket != var.bucket_name
    error_message = "logging_target_bucket must be a different bucket from bucket_name to avoid recursive logging."
  }
}

variable "logging_target_prefix" {
  description = "Key prefix for server access log objects in the target bucket."
  type        = string
  default     = "s3-access-logs/"

  validation {
    condition     = length(var.logging_target_prefix) <= 512 && !startswith(var.logging_target_prefix, "/")
    error_message = "logging_target_prefix must be at most 512 characters and must not start with '/'."
  }
}

################################################################################
# Versioning protection — MFA delete & Object Lock retention (Security / Reliability)
################################################################################

variable "enable_mfa_delete" {
  description = "Require MFA to permanently delete object versions or change the versioning state. Can only be enabled by the AWS account root user with its MFA device; requires enable_versioning = true and `mfa`. Disabling it later must also be done by the root user."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_mfa_delete || var.enable_versioning
    error_message = "enable_versioning must be true when enable_mfa_delete is true."
  }
}

variable "mfa" {
  description = "Root user MFA device serial number (or ARN) and the current 6-digit code, separated by a space, e.g. \"arn:aws:iam::123456789012:mfa/root-account-mfa-device 123456\". Required only when enable_mfa_delete is true; pass at apply time (TF_VAR_mfa), never commit it."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.mfa == null || can(regex("^\\S+ [0-9]{6}$", var.mfa))
    error_message = "mfa must be \"<mfa-serial-or-arn> <6-digit-code>\"."
  }

  validation {
    condition     = !var.enable_mfa_delete || var.mfa != null
    error_message = "mfa is required when enable_mfa_delete is true."
  }
}

variable "object_lock_default_retention_mode" {
  description = "Default Object Lock retention mode applied to new objects: GOVERNANCE (privileged users can override) or COMPLIANCE (nobody, including root, can shorten it). Null applies no default retention. Requires object_lock_enabled = true."
  type        = string
  default     = null

  validation {
    condition     = var.object_lock_default_retention_mode == null || contains(["GOVERNANCE", "COMPLIANCE"], coalesce(var.object_lock_default_retention_mode, "-"))
    error_message = "object_lock_default_retention_mode must be null, GOVERNANCE or COMPLIANCE."
  }

  validation {
    condition     = var.object_lock_default_retention_mode == null || var.object_lock_enabled
    error_message = "object_lock_enabled must be true to set object_lock_default_retention_mode."
  }
}

variable "object_lock_default_retention_days" {
  description = "Default Object Lock retention period in days. Set exactly one of this or object_lock_default_retention_years when a retention mode is set."
  type        = number
  default     = null

  validation {
    condition     = var.object_lock_default_retention_days == null || try(var.object_lock_default_retention_days >= 1 && var.object_lock_default_retention_days <= 36500, false)
    error_message = "object_lock_default_retention_days must be null or between 1 and 36500."
  }

  validation {
    condition = var.object_lock_default_retention_mode == null || (
      (var.object_lock_default_retention_days == null) != (var.object_lock_default_retention_years == null)
    )
    error_message = "Set exactly one of object_lock_default_retention_days or object_lock_default_retention_years when a retention mode is set."
  }
}

variable "object_lock_default_retention_years" {
  description = "Default Object Lock retention period in years. Set exactly one of this or object_lock_default_retention_days when a retention mode is set."
  type        = number
  default     = null

  validation {
    condition     = var.object_lock_default_retention_years == null || try(var.object_lock_default_retention_years >= 1 && var.object_lock_default_retention_years <= 100, false)
    error_message = "object_lock_default_retention_years must be null or between 1 and 100."
  }
}

################################################################################
# Noncurrent version tiering (Cost Optimization)
################################################################################

variable "noncurrent_version_transition_days" {
  description = "Days after an object version becomes noncurrent before it moves to noncurrent_version_transition_storage_class. Null disables the transition. Only applied when versioning is enabled."
  type        = number
  default     = null

  validation {
    condition     = var.noncurrent_version_transition_days == null || try(var.noncurrent_version_transition_days >= 1 && var.noncurrent_version_transition_days <= 3650, false)
    error_message = "noncurrent_version_transition_days must be null or between 1 and 3650."
  }

  validation {
    condition     = var.noncurrent_version_transition_days == null || !contains(["STANDARD_IA", "ONEZONE_IA"], var.noncurrent_version_transition_storage_class) || try(var.noncurrent_version_transition_days >= 30, false)
    error_message = "noncurrent_version_transition_days must be at least 30 for STANDARD_IA or ONEZONE_IA."
  }

  validation {
    condition     = var.noncurrent_version_transition_days == null || var.noncurrent_version_expiration_days == null || try(var.noncurrent_version_transition_days < var.noncurrent_version_expiration_days, false)
    error_message = "noncurrent_version_transition_days must be less than noncurrent_version_expiration_days."
  }
}

variable "noncurrent_version_transition_storage_class" {
  description = "Storage class for noncurrent object versions: STANDARD_IA, ONEZONE_IA, INTELLIGENT_TIERING, GLACIER_IR, GLACIER or DEEP_ARCHIVE."
  type        = string
  default     = "GLACIER_IR"

  validation {
    condition     = contains(["STANDARD_IA", "ONEZONE_IA", "INTELLIGENT_TIERING", "GLACIER_IR", "GLACIER", "DEEP_ARCHIVE"], var.noncurrent_version_transition_storage_class)
    error_message = "noncurrent_version_transition_storage_class must be one of: STANDARD_IA, ONEZONE_IA, INTELLIGENT_TIERING, GLACIER_IR, GLACIER, DEEP_ARCHIVE."
  }
}

################################################################################
# Bucket policy guardrails (Security)
################################################################################

variable "deny_ssec_uploads" {
  description = "Deny uploads that use SSE-C (customer-provided keys), which bypass KMS key policies and CloudTrail key auditing."
  type        = bool
  default     = true
}

variable "enforce_bucket_kms_key" {
  description = "For SSE-KMS/DSSE-KMS buckets, deny uploads that explicitly request a KMS key other than the bucket's key. Ignored for SSE-S3."
  type        = bool
  default     = true
}

variable "allowed_organization_id" {
  description = "AWS Organizations ID (o-xxxxxxxxxx). When set, the bucket policy denies requests from principals outside the organization (AWS service principals are exempt)."
  type        = string
  default     = null

  validation {
    condition     = var.allowed_organization_id == null || can(regex("^o-[a-z0-9]{10,32}$", var.allowed_organization_id))
    error_message = "allowed_organization_id must be null or a valid Organizations ID, e.g. o-a1b2c3d4e5."
  }
}

variable "allowed_vpc_endpoint_ids" {
  description = "VPC endpoint IDs (vpce-...). When non-empty, the bucket policy denies requests that do not arrive through one of these endpoints. Add console/CI/break-glass roles to vpce_policy_exempt_principal_arns to avoid locking yourself out."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for id in var.allowed_vpc_endpoint_ids : can(regex("^vpce-[0-9a-f]{8,17}$", id))])
    error_message = "Each allowed_vpc_endpoint_ids entry must look like vpce-0123456789abcdef0."
  }
}

variable "vpce_policy_exempt_principal_arns" {
  description = "IAM principal ARNs (wildcards allowed) exempt from the VPC endpoint restriction, e.g. a Terraform deployment role or break-glass admin role. The module's replication role is always exempt."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for arn in var.vpce_policy_exempt_principal_arns : can(regex("^arn:aws[a-zA-Z-]*:(iam|sts)::[0-9]{12}:.+$", arn))])
    error_message = "Each vpce_policy_exempt_principal_arns entry must be an IAM or STS principal ARN."
  }
}

################################################################################
# Observability (Operational Excellence)
################################################################################

variable "logging_partitioned_prefix" {
  description = "Write server access logs with date-based partitioned keys ([prefix][SourceAccountId]/[SourceRegion]/[SourceBucket]/[YYYY]/[MM]/[DD]/...) for efficient Athena queries."
  type        = bool
  default     = true
}

variable "enable_eventbridge_notifications" {
  description = "Send all S3 object-level events to Amazon EventBridge (default event bus) so they can be routed by rules."
  type        = bool
  default     = true
}

variable "enable_request_metrics" {
  description = "Enable 1-minute CloudWatch request metrics for the whole bucket (filter ID EntireBucket). Incurs CloudWatch custom metric charges."
  type        = bool
  default     = false
}

variable "create_cloudwatch_alarms" {
  description = "Create CloudWatch alarms on the bucket's 4xxErrors and 5xxErrors request metrics. Requires enable_request_metrics = true."
  type        = bool
  default     = false

  validation {
    condition     = !var.create_cloudwatch_alarms || var.enable_request_metrics
    error_message = "enable_request_metrics must be true when create_cloudwatch_alarms is true."
  }
}

variable "alarm_actions" {
  description = "ARNs (e.g. SNS topics) notified when an alarm changes to ALARM or back to OK."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for arn in var.alarm_actions : can(regex("^arn:aws[a-zA-Z-]*:[a-z0-9-]+:[a-z0-9-]*:[0-9]{12}:.+$", arn))])
    error_message = "Each alarm_actions entry must be a valid ARN, e.g. arn:aws:sns:us-east-1:123456789012:alerts."
  }
}

variable "alarm_5xx_errors_threshold" {
  description = "Alarm when the sum of 5xxErrors in one period exceeds this value."
  type        = number
  default     = 5

  validation {
    condition     = var.alarm_5xx_errors_threshold >= 0
    error_message = "alarm_5xx_errors_threshold must be >= 0."
  }
}

variable "alarm_4xx_errors_threshold" {
  description = "Alarm when the sum of 4xxErrors (e.g. AccessDenied) in one period exceeds this value."
  type        = number
  default     = 100

  validation {
    condition     = var.alarm_4xx_errors_threshold >= 0
    error_message = "alarm_4xx_errors_threshold must be >= 0."
  }
}

variable "alarm_period_seconds" {
  description = "Alarm evaluation period in seconds."
  type        = number
  default     = 300

  validation {
    condition     = contains([60, 300, 900, 3600], var.alarm_period_seconds)
    error_message = "alarm_period_seconds must be one of 60, 300, 900, 3600."
  }
}

variable "alarm_evaluation_periods" {
  description = "Number of consecutive periods that must breach the threshold before alarming."
  type        = number
  default     = 1

  validation {
    condition     = var.alarm_evaluation_periods >= 1 && var.alarm_evaluation_periods <= 24
    error_message = "alarm_evaluation_periods must be between 1 and 24."
  }
}

variable "enable_inventory" {
  description = "Enable an S3 Inventory report for the whole bucket (used for audits of encryption, replication and Object Lock status)."
  type        = bool
  default     = false
}

variable "inventory_destination_bucket_arn" {
  description = "ARN of the bucket that receives inventory reports. Required when enable_inventory is true; its bucket policy must allow s3.amazonaws.com to write."
  type        = string
  default     = null

  validation {
    condition     = var.inventory_destination_bucket_arn == null || can(regex("^arn:aws[a-zA-Z-]*:s3:::[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.inventory_destination_bucket_arn))
    error_message = "inventory_destination_bucket_arn must be null or a valid S3 bucket ARN, e.g. arn:aws:s3:::my-inventory-bucket."
  }

  validation {
    condition     = !var.enable_inventory || var.inventory_destination_bucket_arn != null
    error_message = "inventory_destination_bucket_arn is required when enable_inventory is true."
  }
}

variable "inventory_frequency" {
  description = "How often inventory reports are produced: Daily or Weekly."
  type        = string
  default     = "Weekly"

  validation {
    condition     = contains(["Daily", "Weekly"], var.inventory_frequency)
    error_message = "inventory_frequency must be Daily or Weekly."
  }
}

variable "inventory_format" {
  description = "Inventory report format: CSV, ORC or Parquet."
  type        = string
  default     = "Parquet"

  validation {
    condition     = contains(["CSV", "ORC", "Parquet"], var.inventory_format)
    error_message = "inventory_format must be CSV, ORC or Parquet."
  }
}

variable "inventory_optional_fields" {
  description = "Optional metadata fields included in inventory reports."
  type        = list(string)
  default = [
    "Size", "LastModifiedDate", "StorageClass", "ETag", "IsMultipartUploaded", "ReplicationStatus",
    "EncryptionStatus", "BucketKeyStatus", "IntelligentTieringAccessTier", "ObjectLockMode",
    "ObjectLockRetainUntilDate", "ObjectLockLegalHoldStatus", "ChecksumAlgorithm",
  ]

  validation {
    condition = alltrue([for f in var.inventory_optional_fields : contains([
      "Size", "LastModifiedDate", "StorageClass", "ETag", "IsMultipartUploaded", "ReplicationStatus",
      "EncryptionStatus", "ObjectLockRetainUntilDate", "ObjectLockMode", "ObjectLockLegalHoldStatus",
      "IntelligentTieringAccessTier", "BucketKeyStatus", "ChecksumAlgorithm", "ObjectAccessControlList", "ObjectOwner",
    ], f)])
    error_message = "inventory_optional_fields contains an unsupported field name."
  }
}

################################################################################
# Replication (Reliability)
################################################################################

variable "enable_replication" {
  description = "Replicate all objects to another bucket (Cross-Region Replication for disaster recovery, or Same-Region / cross-account). Requires enable_versioning = true and a versioned destination bucket."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_replication || var.enable_versioning
    error_message = "enable_versioning must be true when enable_replication is true."
  }
}

variable "replication_destination_bucket_arn" {
  description = "ARN of the existing, versioning-enabled destination bucket. Required when enable_replication is true."
  type        = string
  default     = null

  validation {
    condition     = var.replication_destination_bucket_arn == null || can(regex("^arn:aws[a-zA-Z-]*:s3:::[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.replication_destination_bucket_arn))
    error_message = "replication_destination_bucket_arn must be null or a valid S3 bucket ARN."
  }

  validation {
    condition     = !var.enable_replication || var.replication_destination_bucket_arn != null
    error_message = "replication_destination_bucket_arn is required when enable_replication is true."
  }
}

variable "replication_role_arn" {
  description = "Existing IAM role S3 assumes for replication. Null lets the module create a least-privilege role."
  type        = string
  default     = null

  validation {
    condition     = var.replication_role_arn == null || can(regex("^arn:aws[a-zA-Z-]*:iam::[0-9]{12}:role/.+$", var.replication_role_arn))
    error_message = "replication_role_arn must be null or a valid IAM role ARN."
  }
}

variable "replication_storage_class" {
  description = "Storage class for replicas in the destination bucket."
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "INTELLIGENT_TIERING", "STANDARD_IA", "ONEZONE_IA", "GLACIER_IR", "GLACIER", "DEEP_ARCHIVE"], var.replication_storage_class)
    error_message = "replication_storage_class must be one of: STANDARD, INTELLIGENT_TIERING, STANDARD_IA, ONEZONE_IA, GLACIER_IR, GLACIER, DEEP_ARCHIVE."
  }
}

variable "replication_destination_kms_key_arn" {
  description = "KMS key ARN in the destination region used to encrypt replicas. Required when encryption_type is SSE-KMS or DSSE-KMS and replication is enabled."
  type        = string
  default     = null

  validation {
    condition     = var.replication_destination_kms_key_arn == null || can(regex("^arn:aws[a-zA-Z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/.+$", var.replication_destination_kms_key_arn))
    error_message = "replication_destination_kms_key_arn must be null or a valid KMS key ARN."
  }

  validation {
    condition     = !var.enable_replication || var.encryption_type == "SSE-S3" || var.replication_destination_kms_key_arn != null
    error_message = "replication_destination_kms_key_arn is required to replicate KMS-encrypted objects (encryption_type SSE-KMS or DSSE-KMS)."
  }
}

variable "replication_destination_account_id" {
  description = "AWS account ID that owns the destination bucket, for cross-account replication. When set, replica ownership is transferred to that account."
  type        = string
  default     = null

  validation {
    condition     = var.replication_destination_account_id == null || can(regex("^[0-9]{12}$", var.replication_destination_account_id))
    error_message = "replication_destination_account_id must be null or a 12-digit AWS account ID."
  }
}

variable "replication_replicate_delete_markers" {
  description = "Replicate delete markers to the destination. Keep false to protect replicas from accidental or malicious deletes."
  type        = bool
  default     = false
}

variable "replication_time_control" {
  description = "Enable S3 Replication Time Control (15-minute SLA) and replication metrics. Adds per-GB charges."
  type        = bool
  default     = false
}

################################################################################
# Performance Efficiency & Cost
################################################################################

variable "enable_transfer_acceleration" {
  description = "Enable S3 Transfer Acceleration for long-distance uploads/downloads via CloudFront edge locations. Not supported for bucket names that contain dots."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_transfer_acceleration || !strcontains(var.bucket_name, ".")
    error_message = "Transfer Acceleration is not supported for bucket names that contain dots (.)."
  }
}

variable "enable_requester_pays" {
  description = "Make requesters pay for requests and data transfer (useful for shared datasets). Anonymous access is not possible with Requester Pays."
  type        = bool
  default     = false
}
