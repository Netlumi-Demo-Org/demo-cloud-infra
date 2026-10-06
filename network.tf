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
    cidr_blocks = ["35.235.240.0/20"]
  }

  egress {
    description = "All outbound"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  # This security group is intended to be attached to EC2 instances or other resources
  # that require bastion access. The CKV2_AWS_5 violation indicates that the security group
  # is not currently attached to any resource. This is a common pattern for security groups
  # that are defined as templates to be referenced by other resources.
  # The fix for this violation is to ensure that this security group is referenced by
  # an aws_instance, aws_launch_template, aws_autoscaling_group, or similar resource.
  # Since the context only provides the security group definition, and not the resource
  # it should be attached to, no direct change is made to this block.
  # The user should ensure that this security group is used in the `vpc_security_group_ids`
  # attribute of an EC2 instance or other relevant resource.
}
