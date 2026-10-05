# demo-cloud-infra

AWS infrastructure for **Acme Ledger**, a fictional invoicing SaaS used in the
Netlumi public demo. It is real, applyable Terraform with a handful of
**deliberate misconfigurations**. Netlumi scans the AWS account, maps each
finding back to this code through the Terraform state, and opens a fix pull
request here.

**Demo content. Nothing here belongs to a real company, and nothing in it is
publicly reachable.**

## Architecture

```
                         Acme Ledger (us-east-1)
  ┌──────────────────────────────────────────────────────────────────┐
  │  S3                                                              │
  │    acme-ledger-app-uploads-<acct>  (module secure-bucket, v1.0.0)│
  │    acme-ledger-reports-<acct>      (invoice PDFs, CSV exports)   │
  │    acme-ledger-logs-<acct>         (reference "good" bucket)     │
  │                                                                  │
  │  DynamoDB   acme-ledger-invoices          (on-demand)            │
  │  SQS        acme-ledger-invoice-events  ─► ...-invoice-events-dlq│
  │  SNS        acme-ledger-billing-alerts                           │
  │  Logs       /acme-ledger/app (365 d), /acme-ledger/ci-deploy     │
  │                                                                  │
  │  IAM roles  acme-ledger-ci-deployer   (trusts this account only) │
  │             acme-ledger-app-runtime   (trusts this account only) │
  │  EC2        acme-ledger-bastion security group (attached to      │
  │             nothing, default VPC)                                │
  └──────────────────────────────────────────────────────────────────┘
  State: s3://acme-ledger-tfstate-<acct>/demo-cloud-infra/terraform.tfstate
         (created by bootstrap/, S3 native lockfile)
```

There is no compute: no EC2 instances, NAT gateways, load balancers, databases
or customer-managed KMS keys. Empty buckets, an empty on-demand table, idle
queues, a topic without subscribers and empty log groups cost close to
nothing (cents a month at most).

Every resource is tagged `purpose = netlumi-demo` and `owner = netlumi`
(provider `default_tags`).

## Planted findings

Rule files live in the Netlumi repository under
`core-services/dumb-detector/rules/final-dsl-rules/`; the line is the rule's
`match` condition.

| # | Terraform address | File | Expected rule id | Rule file:line | Fix the PR should make |
|---|---|---|---|---|---|
| 1 | `module.app_uploads.aws_s3_bucket.this` (call passes `versioning_enabled = false`) | `s3.tf` | `netlumi_s3_bucket_object_versioning` | `s3/netlumi_s3_bucket_object_versioning.yaml:13` (`versioningStatus != "Enabled"`) | Change the module call's input to `versioning_enabled = true`; the module is not edited |
| 2 | `aws_s3_bucket.reports` (no `aws_s3_bucket_public_access_block`; default BPA stripped once at create) | `s3.tf` | `netlumi_s3_bucket_block_public_access` | `s3/netlumi_s3_bucket_block_public_access.yaml:16-20` (any of the four settings `!= true`) | Add the missing `aws_s3_bucket_public_access_block` |
| 3 | `aws_iam_policy.ci_deploy` (`iam:PassRole` + `lambda:CreateFunction` on `*`, attached to `ci-deployer`) | `iam.tf` | `netlumi_iam_policy_allows_privilege_escalation` | `iam/netlumi_iam_policy_allows_privilege_escalation.yaml:14-16` (customer managed, attached, `allowsPrivilegeEscalation`) | Scope `iam:PassRole` to the app's role ARNs |
| 4 | `aws_iam_role.app_runtime` with inline `aws_iam_role_policy.app_runtime_debug` (`Action "*"`, `Resource "*"`) | `iam.tf` | `netlumi_iam_inline_policy_no_administrative_privileges` (on the role) | `iam/netlumi_iam_inline_policy_no_administrative_privileges.yaml:10` (`inlinePoliciesAllowFullAdmin == true`) | Remove or narrow the wildcard inline policy |
| 5 | `aws_security_group.bastion` (tcp/22 from `0.0.0.0/0`, unattached) | `network.tf` | `netlumi_ec2_securitygroup_allow_ingress_from_internet_to_tcp_port_22` | `ec2/netlumi_ec2_securitygroup_allow_ingress_from_internet_to_tcp_port_22.yaml:15` (`port_exposure.port_22 == true`) | Narrow `cidr_blocks` or remove the rule |
| 6 | `aws_cloudwatch_log_group.ci_deploy` (`retention_in_days = 7`) | `logs.tf` | `netlumi_cloudwatch_log_group_retention_policy_specific_days_enabled` | `cloudwatch/netlumi_cloudwatch_log_group_retention_policy_specific_days_enabled.yaml:13-14` (`0 < RetentionInDays < 365`) | `retention_in_days = 365` |
| 7 | `aws_sqs_queue.invoice_events` (`sqs_managed_sse_enabled = false`, no KMS key) | `messaging.tf` | `netlumi_sqs_queues_server_side_encryption_enabled` and `netlumi_sqs_queue_encryption` | `sqs/netlumi_sqs_queues_server_side_encryption_enabled.yaml:15-16`, `sqs/netlumi_sqs_queue_encryption.yaml:14-15` | `sqs_managed_sse_enabled = true` |
| 8 | `aws_sns_topic.billing_alerts` (no `kms_master_key_id`) | `messaging.tf` | `netlumi_sns_topics_kms_encryption_at_rest_enabled` | `sns/netlumi_sns_topics_kms_encryption_at_rest_enabled.yaml:13` (`kmsMasterKeyId == null`; empty counts as null) | `kms_master_key_id = "alias/aws/sns"` |
| 9 | `aws_dynamodb_table.invoices` (PITR off) | `dynamodb.tf` | `netlumi_dynamodb_tables_pitr_enabled` | `dynamodb/netlumi_dynamodb_tables_pitr_enabled.yaml:14` | `point_in_time_recovery { enabled = true }` |
| 10 | `aws_dynamodb_table.invoices` (deletion protection off) | `dynamodb.tf` | `netlumi_dynamodb_table_deletion_protection_enabled` | `dynamodb/netlumi_dynamodb_table_deletion_protection_enabled.yaml:14` | `deletion_protection_enabled = true` |

What is deliberately clean, for contrast: the logs bucket (Block Public Access,
versioning, encryption, lifecycle), the state bucket (bootstrap/), the
`/acme-ledger/app` log group (365 days), the dead-letter queue (SSE-SQS) and the
least-privilege `acme-ledger-app-data-access` policy.

Notes:

- **(2)** S3 turns Block Public Access on for every new bucket, so a bucket
  that only lacks the Terraform resource would scan clean.
  `terraform_data.reports_strip_default_bpa` runs
  `aws s3api delete-public-access-block` once, right after the bucket is
  created, so **the machine running apply needs the AWS CLI** with the same
  credentials. The bucket stays private: no bucket policy, no ACL grants, ACLs
  disabled. Whether `netlumi_s3_bucket_level_public_access_block` also fires
  depends on the account-level Block Public Access setting.
- **(5)** needs a default VPC in us-east-1.
- **(6)** fires only for `0 < retention < 365`. A log group with no retention
  never expires and does not fire it.
- **(7)** new queues get SSE-SQS by default, so it is switched off explicitly.
  Both SQS rules match the same condition; expect two findings on the queue.
- Broader rules will also fire and are not the point of the demo, for example:
  S3 server access logging, object lock, cross-region replication, MFA delete
  and KMS (rather than SSE-S3) encryption; SQS and DynamoDB not using a
  customer-managed KMS key (also on the dead-letter queue); DynamoDB not in a
  backup plan; unused security group; log groups not KMS-encrypted; roles
  without a permissions boundary; required-tag rules (`Application`,
  `CostCenter`, ...).

## State

The applied state lives in `s3://acme-ledger-tfstate-<account id>/demo-cloud-infra/terraform.tfstate`
(us-east-1). Netlumi reads it to map each live resource to the line of Terraform that declares it,
which is what lets a fix arrive as a pull request against this repository.

## Apply

Requires Terraform >= 1.10 (S3 native lockfile) and the AWS CLI. Run with
credentials for the target account. The provider has
`allowed_account_ids = [var.aws_account_id]` and the variable has no default,
so nothing runs until you name the account, and nothing runs against any other
account.

The `app_uploads` module comes from
`git::https://github.com/Netlumi-Demo-Org/demo-terraform-modules.git//modules/secure-bucket?ref=v1.0.0`,
so that repository and its `v1.0.0` tag must exist before `terraform init`.

```bash
export AWS_PROFILE=<profile-for-the-demo-account>
ACCOUNT_ID=<12-digit-account-id>

# 1. State bucket (once). Local state stays in bootstrap/ and is git-ignored.
cd bootstrap
terraform init
terraform plan -var aws_account_id=$ACCOUNT_ID -out=bootstrap.tfplan
terraform apply bootstrap.tfplan

# 2. Main stack
cd ..
terraform init -backend-config="bucket=acme-ledger-tfstate-$ACCOUNT_ID"
terraform plan -var aws_account_id=$ACCOUNT_ID -out=demo.tfplan
# review the plan, then:
terraform apply demo.tfplan
```

Then connect the account and this repository to Netlumi and let the scheduled
scan run.

## Destroy

**Never run a destroy without Prem's explicit go-ahead.** The demo account and
this stack are shared by every demo visitor.

```bash
terraform plan -destroy -var aws_account_id=$ACCOUNT_ID -out=destroy.tfplan
terraform apply destroy.tfplan
```

Demo buckets use `force_destroy = true`, so a destroy also deletes their
objects. The state bucket in `bootstrap/` has `prevent_destroy` and is removed
only deliberately, after the main stack is gone.

## Checks

```bash
terraform fmt -recursive -check
(cd bootstrap && terraform init -backend=false && terraform validate)
terraform init -backend=false && terraform validate   # needs the module tag to exist
```

## Licence

MIT. See [LICENSE](LICENSE).
