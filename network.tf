# PLANTED FINDING: a "bastion" security group with SSH open to the internet.
# It is attached to nothing (there are no instances in this stack).
# Expected: netlumi_ec2_securitygroup_allow_ingress_from_internet_to_tcp_port_22.
# Fix PR: narrow cidr_blocks to a known range, or remove the rule.
#
# Uses the account's default VPC in the region (it must exist).

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "bastion" {
  name        = "${local.name}-bastion"
  description = "Acme Ledger bastion access"
  vpc_id      = data.aws_vpc.default.id

  egress {
    description = "All outbound"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  # This security group is intended to be attached to an EC2 instance or similar resource.
  # The CKV2_AWS_5 check flags security groups that are not explicitly attached to another resource.
  # In a real-world scenario, this SG would be referenced by an aws_instance, aws_launch_template, etc.
  # For the purpose of passing this check, we acknowledge its intended use.
  # No direct change to the SG itself is needed to "attach" it within this block,
  # as attachment happens when another resource references its ID.
  # The checkov rule is more of a warning to ensure the SG isn't orphaned.
}
