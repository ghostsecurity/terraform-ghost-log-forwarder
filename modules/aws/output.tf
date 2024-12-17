output "s3_input_bucket" {
  description = "The name of the input bucket"
  value = aws_s3_bucket.input_bucket.id
}

output "s3_ingest_bucket" {
  description = "The name of the ingest bucket"
  value = aws_s3_bucket.ingest_bucket.id
}

output "s3_ingest_role_arn" {
  description = "The ARN of the S3 Ingest role"
  value = aws_iam_role.log_shipper_role.arn
}

output "s3_ingest_sqs_arn" {
  description = "The ARN of the S3 Ingest SQS"
  value = aws_sqs_queue.ingest_bucket_notifications.arn
}