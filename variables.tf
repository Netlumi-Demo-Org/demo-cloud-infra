variable "aws_account_id" {
  description = "AWS account this stack is applied to. Required; the provider refuses any other account."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account id."
  }
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}
