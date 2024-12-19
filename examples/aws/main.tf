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

provider "ghost" {
}

module "dev-alb-forwarder" {
  source = "../../"
  name   = "dev-alb-forwarder"
}

data "aws_s3_bucket" "source" {
  bucket = "source-bucket-name"
}

data "aws_s3_bucket" "dest" {
  bucket = module.dev-alb-forwarder.s3_input_bucket
}

// Copied from the AWS terraform docs
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
  name               = "ghost-dev-log-replication"
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
  name   = "ghost-dev-log-replication"
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
      prefix = "AWSLOGS"
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
