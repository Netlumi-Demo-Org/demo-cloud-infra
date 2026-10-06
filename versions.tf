terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  # Remote state in the bucket created by ./bootstrap (the demo account's).
  # To apply in another account, override it at init time:
  #   terraform init -backend-config="bucket=acme-ledger-tfstate-<ACCOUNT_ID>"
  # Credentials come from the environment (AWS_PROFILE or the default chain).
  backend "s3" {
    bucket       = "acme-ledger-tfstate-669958786936"
    key          = "demo-cloud-infra/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  # No default on purpose: the provider refuses to run until the target
  # account is named, and then refuses every other account.
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = local.common_tags
  }
}
