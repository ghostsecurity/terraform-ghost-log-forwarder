locals {
  lambda_image = "007807482039.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/forwarder:v0.5.0"
  default_tags = {
    "ghost:forwarder_name" = var.name
  }

  tags = merge(local.default_tags, var.tags)
}

// used to find Lambda image for this region
data "aws_region" "current" {}
// used in SQS policy
data "aws_caller_identity" "current" {}
