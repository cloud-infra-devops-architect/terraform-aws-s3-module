# TFLint configuration for terraform-aws-s3-module
# Rulesets: https://github.com/terraform-linters/tflint-ruleset-aws
#           https://github.com/terraform-linters/tflint-ruleset-terraform
# Run locally: tflint --init && tflint --recursive --config "$(pwd)/.tflint.hcl"

tflint {
  required_version = ">= 0.50.0"
}

config {
  format           = "compact"
  call_module_type = "all"
  force            = false
}

plugin "terraform" {
  enabled = true
  version = "0.13.0"
  source  = "github.com/terraform-linters/tflint-ruleset-terraform"
  preset  = "all"
}

plugin "aws" {
  enabled = true
  version = "0.44.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# ── Terraform language rules ──────────────────────────────────────────────────
rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_standard_module_structure" {
  enabled = true
}

rule "terraform_module_pinned_source" {
  enabled = true
}

rule "terraform_deprecated_index" {
  enabled = true
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}

# ── AWS rules ─────────────────────────────────────────────────────────────────
rule "aws_resource_missing_tags" {
  enabled = true
  tags = [
    "Name",
    "Owner",
    "Project",
    "Environment",
    "Email",
  ]
  # aws_kms_alias is not taggable.
  exclude = ["aws_kms_alias"]
}

rule "aws_s3_bucket_name" {
  enabled = true
  regex   = "^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$"
}
