// InputBucket: S3 input bucket to be replicated to by customers
resource "aws_s3_bucket" "input_bucket" {
  bucket = "ghost-${local.log_forwarder_id}-input"

  force_destroy = true
  tags          = local.tags
}

// InputBucket: S3 object versioning is required in order for objects
// to be replicated into this bucket.
resource "aws_s3_bucket_versioning" "input" {
  bucket = aws_s3_bucket.input_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
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

  force_destroy = true
  tags          = local.tags
}
