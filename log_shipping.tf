// LogShipper: Create a log forwarder in the Ghost platform in order to get the federated identity
// details for creating the log_shipper_assume_role.
resource "ghost_log_forwarder" "forwarder" {
  name = var.name
}

// LogShipper: Allow Ghost service account to assume role in order to copy logs into the platform
data "aws_iam_policy_document" "log_shipper_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = ["accounts.google.com"]
    }
    condition {
      test     = "Null"
      variable = "accounts.google.com:sub"
      values   = [false]
    }
    condition {
      test     = "StringEquals"
      variable = "accounts.google.com:sub"
      values   = [ghost_log_forwarder.forwarder.subject_id]
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
  name        = "ghost-${local.log_forwarder_id}-shipper"
  description = "IAM policy for Ghost Log Shipper to send logs"
  policy      = data.aws_iam_policy_document.log_shipper_policy.json
}

// LogShipper: Role
resource "aws_iam_role" "log_shipper_role" {
  name               = "ghost-${local.log_forwarder_id}-ingest"
  description        = "Allows read access to the ingest bucket"
  assume_role_policy = data.aws_iam_policy_document.log_shipper_assume_role.json

  force_detach_policies = true

  tags = local.tags
}

// LogShipper: Permission to access buckets and SQS notifications
resource "aws_iam_role_policy_attachment" "log_shipper_role_bucket_access" {
  policy_arn = aws_iam_policy.log_shipper_policy.arn
  role       = aws_iam_role.log_shipper_role.name
}

// LogShipper: SQS queue
resource "aws_sqs_queue" "ingest_bucket_notifications" {
  sqs_managed_sse_enabled = true
  name                    = "ghost-${local.log_forwarder_id}-ingest"

  tags = local.tags
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
      type        = "Service"
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

// LogShipper: Send notifications to queue for new files in ingest bucket
resource "aws_s3_bucket_notification" "ingest" {
  bucket = aws_s3_bucket.ingest_bucket.id

  queue {
    queue_arn     = aws_sqs_queue.ingest_bucket_notifications.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".gz"
  }
  depends_on = [
    aws_sqs_queue_policy.ingest_bucket_notifications,
  ]
}

// LogShipper: report back to the Ghost platform the details necessary
// for copying files from the ingest bucket using federate GCP identity.
resource "ghost_aws_log_source" "source" {
  log_forwarder_id = ghost_log_forwarder.forwarder.id
  s3_bucket_name   = aws_s3_bucket.ingest_bucket.id
  role_arn         = aws_iam_role.log_shipper_role.arn
  sqs_arn          = aws_sqs_queue.ingest_bucket_notifications.arn
  account_id       = data.aws_caller_identity.current.account_id
  region           = data.aws_region.current.name

  depends_on = [
    aws_sqs_queue_policy.ingest_bucket_notifications,
    aws_iam_role_policy_attachment.log_shipper_role_bucket_access,
  ]
}
