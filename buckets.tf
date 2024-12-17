// InputBucket: S3 input bucket to be replicated to by customers
resource "aws_s3_bucket" "input_bucket" {
  bucket = "ghost-${local.log_forwarder_id}-input"

  tags = local.tags
}

// InputBucket: Lifecycle. Clear out logs from the input bucket after a day.
resource "aws_s3_bucket_lifecycle_configuration" "input_bucket" {
  bucket = aws_s3_bucket.input_bucket.id
  rule {
    id     = "expiration"
    status = "Enabled"
    expiration {
      days = 1
    }
  }
}

// IngestBucket: S3 bucket Ghost Platform gets cloud-agnostic logs from
resource "aws_s3_bucket" "ingest_bucket" {
  bucket = "ghost-${local.log_forwarder_id}-ingest"

  tags = local.tags
}