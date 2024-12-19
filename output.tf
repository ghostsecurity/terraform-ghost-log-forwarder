output "s3_input_bucket" {
  description = "The name of the input bucket"
  value       = aws_s3_bucket.input_bucket.id
}
