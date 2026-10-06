# ---------------------------------------------------------------------------
# Logs bucket: the well-configured reference bucket (no planted finding).
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "logs" {
  bucket        = "${local.name}-logs-${local.suffix}"
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 400
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.logs]
}

# ---------------------------------------------------------------------------
# Reports bucket: monthly invoice PDFs and CSV exports.
#
# PLANTED FINDING: no aws_s3_bucket_public_access_block in code.
# Expected: netlumi_s3_bucket_block_public_access.
# Fix PR: add the missing aws_s3_bucket_public_access_block.
#
# S3 turns Block Public Access on for every new bucket, so a bucket that only
# lacks the Terraform resource would scan clean. terraform_data.reports_strip_default_bpa
# removes that default once, right after the bucket is created (the machine
# running apply needs the AWS CLI). The bucket stays private: no bucket policy,
# no ACL grants, and ACLs are disabled (BucketOwnerEnforced, the S3 default).
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "reports" {
  bucket        = "${local.name}-reports-${local.suffix}"
  force_destroy = true
}

resource "terraform_data" "reports_strip_default_bpa" {
  triggers_replace = [aws_s3_bucket.reports.id]

  provisioner "local-exec" {
    command = "aws s3api delete-public-access-block --bucket ${aws_s3_bucket.reports.id} --region ${var.region}"
  }
}

resource "aws_s3_bucket_versioning" "reports" {
  bucket = aws_s3_bucket.reports.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "reports" {
  bucket = aws_s3_bucket.reports.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# ---------------------------------------------------------------------------
# App uploads bucket: customer-uploaded receipts and attachments, built with
# the shared secure-bucket module.
#
# PLANTED FINDING: the module call turns versioning off.
# Expected: netlumi_s3_bucket_object_versioning on
# module.app_uploads.aws_s3_bucket.this.
# Fix PR: change this call's input to versioning_enabled = true (the module
# itself is fine and is not edited).
# ---------------------------------------------------------------------------

module "app_uploads" {
  source = "git::https://github.com/Netlumi-Demo-Org/demo-terraform-modules.git//modules/secure-bucket?ref=v1.0.0"

  bucket_name        = "${local.name}-app-uploads-${local.suffix}"
  versioning_enabled = false
  force_destroy      = true
}

resource "aws_s3_bucket_public_access_block" "reports" {
  bucket = aws_s3_bucket.reports.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
