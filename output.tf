output "s3_input_bucket" {
  description = "The name of the input bucket"
  value       = aws_s3_bucket.input_bucket.id
}

output "lambda_role_arn" {
  description = "The ARN of the IAM Role used by the Log Processing Lambda Function to access Secrets and S3"
  value       = aws_iam_role.log_converter_role.arn
}

output "lambda_arn" {
  description = "The ARN of the Log Processing Lambda Function"
  value       = aws_lambda_function.log_converter.arn
}
