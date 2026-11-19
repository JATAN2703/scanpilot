terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.80"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4"
    }
  }

  # State lives in the bootstrap bucket (it survives terraform destroy).
  # Pass the bucket name at init:
  #   terraform init -backend-config="bucket=scanpilot-tfstate-<account_id>"
  backend "s3" {
    key          = "scanpilot/main.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = "ScanPilot"
      Owner   = "jatan"
    }
  }
}
