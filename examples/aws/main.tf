terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.81.0"
    }
    ghost = {
      source  = "ghostsecurity/ghost",
      version = "~> 0.1.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

# Configure the provider. A valid API key must exist in the GHOST_API_KEY
# environment variable with read:log_forwarders and write:log_forwarders permissions.
provider "ghost" {
}

# This must be updated to reference an existing S3 bucket that is receiving logs
# from your application load balancer.
data "aws_s3_bucket" "source" {
  bucket = "source-bucket-name"
}

# Deploy the Ghost log forwarder.
# Change the name to something meaningful in your organization.
module "dev-alb-forwarder" {
  source = "ghostsecurity/log-forwarder/ghost"
  name   = "example-forwarder"
}

data "aws_s3_bucket" "dest" {
  bucket = module.dev-alb-forwarder.s3_input_bucket
}

# The following resources configure an example S3 replication policy to
# copy logs from the source bucket to the log forwarder bucket so that they
# will be processed and sent to the Ghost platform.
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "replication" {
  name               = "example-replication-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "replication" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]

    resources = [data.aws_s3_bucket.source.arn]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]

    resources = ["${data.aws_s3_bucket.source.arn}/*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
    ]

    resources = ["${data.aws_s3_bucket.dest.arn}/*"]
  }
}

resource "aws_iam_policy" "replication" {
  name   = "example-replication-policy"
  policy = data.aws_iam_policy_document.replication.json
}

resource "aws_iam_role_policy_attachment" "replication" {
  role       = aws_iam_role.replication.name
  policy_arn = aws_iam_policy.replication.arn
}

resource "aws_s3_bucket_replication_configuration" "replication" {
  role   = aws_iam_role.replication.arn
  bucket = data.aws_s3_bucket.source.id

  rule {
    id = "AWSLogs"

    filter {
      prefix = "AWSLogs"
    }

    status = "Enabled"

    delete_marker_replication {
      status = "Enabled"
    }

    destination {
      bucket        = data.aws_s3_bucket.dest.arn
      storage_class = "STANDARD"
    }
  }
}
