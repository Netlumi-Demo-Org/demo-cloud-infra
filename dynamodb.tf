# PLANTED FINDING: the invoices table has neither point-in-time recovery nor
# deletion protection (both are off by default).
# Expected: netlumi_dynamodb_tables_pitr_enabled and
# netlumi_dynamodb_table_deletion_protection_enabled.
# Fix PR: point_in_time_recovery { enabled = true } and
# deletion_protection_enabled = true.
#
# On-demand billing: an empty table costs nothing.

resource "aws_dynamodb_table" "invoices" {
  name         = "${local.name}-invoices"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "tenant_id"
  range_key    = "invoice_id"

  attribute {
    name = "tenant_id"
    type = "S"
  }

  attribute {
    name = "invoice_id"
    type = "S"
  }
}
