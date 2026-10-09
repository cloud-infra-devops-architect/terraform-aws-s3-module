terraform {
  # >= 1.9.0 is required for cross-variable references inside validation blocks.
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # >= 6.0 is required for the resource-level `region` argument used by var.aws_region.
      version = ">= 6.0"
    }
  }
}
