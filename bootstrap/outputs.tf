output "state_bucket" {
  description = "Remote-state bucket for the main root. Pass it to terraform init as -backend-config=\"bucket=<this>\"."
  value       = aws_s3_bucket.state.bucket
}
