
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