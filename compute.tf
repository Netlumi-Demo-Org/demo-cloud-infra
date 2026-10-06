# Compute: the app's public web server and its webhook function. They give
# the demo real attack paths from the internet to the app's data:
#
#   internet -> web instance (public IP, open SG, IMDSv1) -> web role
#            -> sts:AssumeRole app-runtime (inline "*" debug policy) -> everything
#   internet -> webhook function URL (no auth) -> webhook role -> invoices table
#
# The instance has no key pair and runs no service, and the function returns
# a fixed response: the exposure is in the configuration only.
# Cost: a t4g.nano plus its public IPv4 address (a few dollars a month); the
# function costs nothing when idle.

# ---------------------------------------------------------------------------
# Web instance
#
# PLANTED FINDINGS:
#   - HTTP and SSH open to the internet on a public instance.
#     Expected: netlumi_ec2_instance_port_ssh_exposed_to_internet (and the
#     security group rules on aws_security_group.web).
#     Fix PR: narrow cidr_blocks, or drop the SSH rule.
#   - IMDSv1 allowed (http_tokens = "optional").
#     Expected: netlumi_ec2_instance_imdsv2_enabled.
#     Fix PR: metadata_options { http_tokens = "required" }.
#   - The web role may assume app-runtime, whose inline debug policy is "*".
#     Fix PR: remove the AssumeAppRuntime statement (or the debug policy).
# ---------------------------------------------------------------------------

data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

resource "aws_security_group" "web" {
  name        = "${local.name}-web"
  description = "Acme Ledger web server"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "web" {
  name               = "${local.name}-web"
  description        = "Acme Ledger web server"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

data "aws_iam_policy_document" "web" {
  statement {
    sid       = "ReadInvoices"
    effect    = "Allow"
    actions   = ["dynamodb:GetItem", "dynamodb:Query"]
    resources = [aws_dynamodb_table.invoices.arn]
  }

  statement {
    sid       = "ReadReports"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.reports.arn}/*"]
  }

  statement {
    sid       = "AssumeAppRuntime"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.app_runtime.arn]
  }
}

resource "aws_iam_role_policy" "web" {
  name   = "${local.name}-web"
  role   = aws_iam_role.web.id
  policy = data.aws_iam_policy_document.web.json
}

resource "aws_iam_instance_profile" "web" {
  name = "${local.name}-web"
  role = aws_iam_role.web.name
}

resource "aws_instance" "web" {
  ami                         = data.aws_ssm_parameter.al2023_arm64.value
  instance_type               = "t4g.nano"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.web.id]
  iam_instance_profile        = aws_iam_instance_profile.web.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional"
  }

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${local.name}-web"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# ---------------------------------------------------------------------------
# Webhook function
#
# PLANTED FINDING: a public function URL with no authentication.
# Expected: netlumi_awslambda_function_url_public.
# Fix PR: authorization_type = "AWS_IAM".
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "webhook" {
  name               = "${local.name}-webhook"
  description        = "Acme Ledger payment webhook"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

data "aws_iam_policy_document" "webhook" {
  statement {
    sid       = "UpdateInvoices"
    effect    = "Allow"
    actions   = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
    resources = [aws_dynamodb_table.invoices.arn]
  }
}

resource "aws_iam_role_policy" "webhook" {
  name   = "${local.name}-webhook"
  role   = aws_iam_role.webhook.id
  policy = data.aws_iam_policy_document.webhook.json
}

data "archive_file" "webhook" {
  type        = "zip"
  output_path = "${path.module}/.build/webhook.zip"

  source {
    filename = "index.py"
    content  = <<-EOT
      def handler(event, context):
          return {"statusCode": 200, "body": "ok"}
    EOT
  }
}

resource "aws_lambda_function" "webhook" {
  function_name    = "${local.name}-payment-webhook"
  description      = "Acme Ledger payment provider webhook"
  role             = aws_iam_role.webhook.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  architectures    = ["arm64"]
  filename         = data.archive_file.webhook.output_path
  source_code_hash = data.archive_file.webhook.output_base64sha256
  memory_size      = 128
  timeout          = 5
}

resource "aws_lambda_function_url" "webhook" {
  function_name      = aws_lambda_function.webhook.function_name
  authorization_type = "NONE"
}
