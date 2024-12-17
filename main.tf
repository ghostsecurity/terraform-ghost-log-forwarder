locals {
  resource_group   = var.resource_group
  log_forwarder_id = "forwarder_id_from_ghost_resource"
  gcp_sts_sa_id    = "gcp_account_id_from_resource"
  lambda_image     = "007807482039.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/forwarder:11fc3e9"
  tags = {
      "ghost:forwarder_id" = local.log_forwarder_id
      "ResourceGroup"   = local.resource_group
  }
}

// used to find Lambda image for this region
data "aws_region" "current" {}
// used in SQS policy
data "aws_caller_identity" "current" {}
