output "logs_bucket" {
  description = "Logs bucket name."
  value       = aws_s3_bucket.logs.bucket
}

output "reports_bucket" {
  description = "Reports bucket name."
  value       = aws_s3_bucket.reports.bucket
}

output "app_uploads_bucket" {
  description = "App uploads bucket name."
  value       = module.app_uploads.bucket_id
}

output "ci_deployer_role_arn" {
  description = "ARN of the CI deployer role."
  value       = aws_iam_role.ci_deployer.arn
}

output "app_runtime_role_arn" {
  description = "ARN of the application runtime role."
  value       = aws_iam_role.app_runtime.arn
}

output "invoice_events_queue_url" {
  description = "URL of the invoice events queue."
  value       = aws_sqs_queue.invoice_events.url
}

output "billing_alerts_topic_arn" {
  description = "ARN of the billing alerts topic."
  value       = aws_sns_topic.billing_alerts.arn
}

output "invoices_table" {
  description = "Name of the invoices table."
  value       = aws_dynamodb_table.invoices.name
}

output "web_instance_id" {
  description = "ID of the public web instance."
  value       = aws_instance.web.id
}

output "webhook_function_url" {
  description = "Public URL of the payment webhook function."
  value       = aws_lambda_function_url.webhook.function_url
}
