# Bootstrap stack: create once and keep it. The main stack gets destroyed after
# every session, but its state file and the pentest image live here.
# Uses local state (bootstrap/terraform.tfstate).
#
# Learner Lab's service control policy blocks s3:GetBucketObjectLockConfiguration,
# which the aws_s3_bucket resource always reads. So the bucket itself is created
# once in the S3 console (see README) and Terraform manages its settings.

terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.80"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "me" {}

locals {
  state_bucket = "scanpilot-tfstate-${data.aws_caller_identity.me.account_id}"
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = local.state_bucket

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = local.state_bucket
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Sam pushes the pentest image here
resource "aws_ecr_repository" "pentest" {
  name         = "scanpilot-pentest"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

output "state_bucket" {
  value = local.state_bucket
}

output "ecr_repo_url" {
  value = aws_ecr_repository.pentest.repository_url
}
