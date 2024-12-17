// InputBucket: S3 input bucket to be replicated to by customers
resource "aws_s3_bucket" "input_bucket" {
  bucket = "gs-log-forwarder-${local.log_forwarder_id}-input"

  tags = {
    "gs:forwarder_id" = local.log_forwarder_id
    "ResourceGroup"   = local.resource_group
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

// IngestBucket: S3 bucket for cloud-agnostic log format
resource "aws_s3_bucket" "ingest_bucket" {
  bucket = "gs-log-forwarder-${local.log_forwarder_id}-ingest"

  tags = {
    "gs:forwarder_id" = local.log_forwarder_id
    "ResourceGroup"   = local.resource_group
  }
}