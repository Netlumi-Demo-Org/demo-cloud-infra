# Both roles trust only principals of this same account (no external or
# service trust) and are not attached to any instance, function or service.

data "aws_iam_policy_document" "same_account_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.aws_account_id}:root"]
    }
  }
}

# ---------------------------------------------------------------------------
# ci-deployer: assumed by the deployment pipeline.
#
# PLANTED FINDING: the managed policy lets the holder pass ANY role to a new
# Lambda function, which is a path to every permission in the account.
# Expected: netlumi_iam_policy_allows_privilege_escalation (on the policy).
# Fix PR: scope iam:PassRole to the app's own role ARN(s).
# ---------------------------------------------------------------------------

resource "aws_iam_role" "ci_deployer" {
  name               = "${local.name}-ci-deployer"
  description        = "Acme Ledger deployment pipeline"
  assume_role_policy = data.aws_iam_policy_document.same_account_trust.json
}

data "aws_iam_policy_document" "ci_deploy" {
  statement {
    sid    = "DeployFunctions"
    effect = "Allow"
    actions = [
      "lambda:CreateFunction",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:GetFunction",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "PassRolesToFunctions"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ci_deploy" {
  name        = "${local.name}-ci-deploy"
  description = "Lets the pipeline create and update the app's Lambda functions"
  policy      = data.aws_iam_policy_document.ci_deploy.json
}

resource "aws_iam_role_policy_attachment" "ci_deploy" {
  role       = aws_iam_role.ci_deployer.name
  policy_arn = aws_iam_policy.ci_deploy.arn
}

# ---------------------------------------------------------------------------
# app-runtime: the identity the application runs as.
# ---------------------------------------------------------------------------

resource "aws_iam_role" "app_runtime" {
  name               = "${local.name}-app-runtime"
  description        = "Acme Ledger application runtime"
  assume_role_policy = data.aws_iam_policy_document.same_account_trust.json
}

# Least-privilege access to the app's own data (no planted finding).
data "aws_iam_policy_document" "app_data_access" {
  statement {
    sid    = "InvoicesTable"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:Query",
    ]
    resources = [aws_dynamodb_table.invoices.arn]
  }

  statement {
    sid    = "InvoiceEvents"
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]
    resources = [aws_sqs_queue.invoice_events.arn]
  }

  statement {
    sid       = "Uploads"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${module.app_uploads.bucket_arn}/*"]
  }
}

resource "aws_iam_policy" "app_data_access" {
  name        = "${local.name}-app-data-access"
  description = "Acme Ledger runtime access to its table, queue and uploads bucket"
  policy      = data.aws_iam_policy_document.app_data_access.json
}

resource "aws_iam_role_policy_attachment" "app_data_access" {
  role       = aws_iam_role.app_runtime.name
  policy_arn = aws_iam_policy.app_data_access.arn
}

# PLANTED FINDING: an inline "debug" policy granting every action on every
# resource, left behind after an incident.
# Expected: netlumi_iam_inline_policy_no_administrative_privileges (on the role).
# Fix PR: remove or narrow the wildcard statement.

data "aws_iam_policy_document" "app_runtime_debug" {
  statement {
    sid       = "TemporaryDebugAccess"
    effect    = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${local.name}-app-data",
      "arn:aws:s3:::${local.name}-app-data/*"
    ]
  }
}

resource "aws_iam_role_policy" "app_runtime_debug" {
  name   = "${local.name}-app-runtime-debug"
  role   = aws_iam_role.app_runtime.id
  policy = data.aws_iam_policy_document.app_runtime_debug.json
}
