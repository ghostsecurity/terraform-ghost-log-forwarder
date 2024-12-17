locals {
  resource_group   = var.resource_group
  log_forwarder_id = "forwarder_id_from_ghost_resource"
  gcp_sts_sa_id    = "gcp_account_id_from_resource"
  lambda_image     = "007807482039.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/forwarder:11fc3e9"
}

data "aws_region" "current" {}
// used to find Lambda image for this region
data "aws_caller_identity" "current" {}
// used in SQS policy

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

// LogShipper: Allow GCP STS access.
data "aws_iam_policy_document" "log_shipper_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type = "Federated"
      identifiers = ["accounts.google.com"]
    }
    condition {
      test     = "Null"
      variable = "accounts.google.com:sub"
      values = [false]
    }
    condition {
      test     = "StringEquals"
      variable = "accounts.google.com:sub"
      values = [local.gcp_sts_sa_id]
    }
    effect = "Allow"
  }
}

// LogShipper: Get at logs for shipping
data "aws_iam_policy_document" "log_shipper_policy" {
  statement {
    actions = [
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:GetObjectAttributes",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.ingest_bucket.arn,
      "${aws_s3_bucket.ingest_bucket.arn}/*"
    ]
    effect = "Allow"
  }

  statement {
    actions = [
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility",
      "sqs:ReceiveMessage"
    ]
    resources = [
      aws_sqs_queue.ingest_bucket_notifications.arn
    ]
    effect = "Allow"
  }

  statement {
    actions = [
      "s3:DeleteObject"
    ]
    resources = [
      "${aws_s3_bucket.ingest_bucket.arn}/*"
    ]
    effect = "Allow"
  }
}

// LogShipper: IAM policy
resource "aws_iam_policy" "log_shipper_policy" {
  name = "gs-${local.log_forwarder_id}-shipper"
  description = "IAM policy for Ghost Log Shipper to send logs"
  policy = data.aws_iam_policy_document.log_shipper_policy.json
}

// LogShipper: Role
resource "aws_iam_role" "log_shipper_role" {
  name        = "gs-${local.log_forwarder_id}-ingest"
  description = "Allows read access to the ingest bucket"
  assume_role_policy = data.aws_iam_policy_document.log_shipper_assume_role.json

  force_detach_policies = true

  tags = {
    "gs:forwarder_id" = local.log_forwarder_id
    "ResourceGroup"   = local.resource_group
  }
}

// LogShipper: Permission to access buckets and SQS notifications
resource "aws_iam_role_policy_attachment" "log_shipper_role_bucket_access" {
  policy_arn = aws_iam_policy.log_shipper_policy.arn
  role       = aws_iam_role.log_shipper_role.name
}

// LogShipper: SQS queue
resource "aws_sqs_queue" "ingest_bucket_notifications" {
  sqs_managed_sse_enabled = true
  name                    = "gs-log-forwarder-${local.log_forwarder_id}-ingest"

  tags = {
    "gs:forwarder_id" = local.log_forwarder_id
    "ResourceGroup"   = local.resource_group
  }
}

// LogShipper: SQS policy for ingest bucket notifications
data "aws_iam_policy_document" "s3_object_notification" {
  statement {
    actions = ["sqs:SendMessage"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values = [
        data.aws_caller_identity.current.account_id,
      ]
    }
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    resources = [
      aws_sqs_queue.ingest_bucket_notifications.arn,
    ]
  }
}

// LogShipper: Attach policy to queue
resource "aws_sqs_queue_policy" "ingest_bucket_notifications" {
  policy    = data.aws_iam_policy_document.s3_object_notification.json
  queue_url = aws_sqs_queue.ingest_bucket_notifications.id
}

// LogConverter: Lambda function
resource "aws_lambda_function" "log_converter" {
  function_name = "gs-${local.log_forwarder_id}-function" // had resource Group in front before
  image_uri = local.lambda_image
  package_type = "Image"
  architectures = ["arm64"]
  role      = aws_iam_role.log_converter_role.arn
  timeout   = 60

  environment {
    variables = {
      INGEST_BUCKET = aws_s3_bucket.input_bucket.id
      FORWARDER_ID  = local.log_forwarder_id
    }
  }

  tags = {
    "gs:forwarder_id" = local.log_forwarder_id
    "ResourceGroup"   = local.resource_group
  }
}

// LogConverter: Lambda permission
resource "aws_lambda_permission" "log_converter" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.log_converter.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.input_bucket.arn
}

// LogConverter: IAM role
resource "aws_iam_role" "log_converter_role" {
  name = "gs-${local.log_forwarder_id}-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  path                  = "/"
  force_detach_policies = true

  tags = {
    "gs:forwarder_id" = local.log_forwarder_id
    "ResourceGroup"   = local.resource_group
  }
}

// LogConverter: Assume role definition
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    effect = "Allow"
  }
}

// LogConverter: attach ability to get at the buckets
resource "aws_iam_role_policy_attachment" "log_converter_bucket_access" {
  policy_arn = aws_iam_policy.lambda_bucket_access.arn
  role       = aws_iam_role.log_converter_role.name
}

// LogConverter: IAM policy
resource "aws_iam_policy" "lambda_bucket_access" {
  name = "gs-${local.log_forwarder_id}-access"
  description = "IAM policy for Ghost Log Fowarder to access S3 buckets"
  policy = data.aws_iam_policy_document.lambda_bucket_access.json
}

// LogConverter: policy for bucket access
data "aws_iam_policy_document" "lambda_bucket_access" {
  statement {
    actions = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.input_bucket.arn}/*"]
    effect = "Allow"
  }
  statement {
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.ingest_bucket.arn}/*"]
    effect = "Allow"
  }
}