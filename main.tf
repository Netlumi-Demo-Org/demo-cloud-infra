# Acme Ledger: a small invoicing SaaS. This root holds the shared AWS
# footprint of the app (storage, queues, a table, IAM roles, log groups).
# Compute is out of scope here, and nothing in this stack is publicly
# reachable. Several resources carry deliberate misconfigurations for the
# Netlumi demo; each is marked "PLANTED FINDING" and listed in README.md.

locals {
  name   = "acme-ledger"
  suffix = var.aws_account_id

  common_tags = {
    purpose = "netlumi-demo"
    owner   = "netlumi"
  }
}
