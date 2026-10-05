# Application logs: kept for a year (no planted finding).
resource "aws_cloudwatch_log_group" "app" {
  name              = "/acme-ledger/app"
  retention_in_days = 365
}

# PLANTED FINDING: deployment logs kept for only 7 days.
# Expected: netlumi_cloudwatch_log_group_retention_policy_specific_days_enabled
# (fires for 0 < retention < 365).
# Fix PR: retention_in_days = 365 (or more).
resource "aws_cloudwatch_log_group" "ci_deploy" {
  name              = "/acme-ledger/ci-deploy"
  retention_in_days = 7
}
