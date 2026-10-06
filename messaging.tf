# Dead-letter queue: SQS-managed encryption on (no planted finding beyond the
# broad customer-managed-key rule, see README).
resource "aws_sqs_queue" "invoice_events_dlq" {
  name                      = "${local.name}-invoice-events-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

# PLANTED FINDING: invoice events are stored unencrypted at rest. New queues
# get SSE-SQS by default, so it is switched off explicitly here.
# Expected: netlumi_sqs_queues_server_side_encryption_enabled and
# netlumi_sqs_queue_encryption.
# Fix PR: sqs_managed_sse_enabled = true (or a kms_master_key_id).
resource "aws_sqs_queue" "invoice_events" {
  name                       = "${local.name}-invoice-events"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600
  sqs_managed_sse_enabled    = false

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.invoice_events_dlq.arn
    maxReceiveCount     = 5
  })
}

# PLANTED FINDING: billing alerts topic without encryption at rest.
# Expected: netlumi_sns_topics_kms_encryption_at_rest_enabled.
# Fix PR: kms_master_key_id = "alias/aws/sns" (AWS-managed key, no monthly cost).
resource "aws_sns_topic" "billing_alerts" {
  name              = "${local.name}-billing-alerts"
  kms_master_key_id = "alias/aws/sns"
}
