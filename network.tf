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

  ingress {
    description = "SSH"
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["35.235.240.0/20"] # Restricted to GCP IAP range
  }

  egress {
    description = "All outbound"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  # This security group is intended to be attached to EC2 instances or other resources
  # that require bastion access. The attachment itself is done on the resource
  # being protected, not within the security group definition.
  # For example, an aws_instance resource would reference this SG via its vpc_security_group_ids attribute.
}
