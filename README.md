# terraform-ghost-log-forwarder
Terraform module which deploys a [Ghost](https://ghostsecurity.com/) log forwarder to AWS for sending [ALB logs](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-access-logs.html) to the Ghost platform.

Refer to the [Log Based Discovery](https://docs.ghostsecurity.com/en/articles/9471377-log-based-discovery-alpha) documentation for more on how this is used in the Ghost platform.

## Considerations
- Ensure resources created in AWS are unique to avoid naming conflict errors.
- S3 bucket versioning must be enabled on the `source` bucket to allow for S3 bucket replication to be configured.
- Only replicate new log files to the log forwarder bucket. Do not replicate existing objects.
- The [ghost](https://registry.terraform.io/providers/ghostsecurity/ghost) provider requires an API key with `read:log_forwarders` and `write:log_forwarders` permissions.
    - Use the [API Keys](https://app.ghostsecurity.com/settings/apikeys) page to generate a new key.
    - Using an invalid or expired API key will result in an `unexpected status 401` error.

<!-- BEGIN_TF_DOCS -->
## Example
The following example deploys a log forwarder and configures [S3 ojbect replication](https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication.html) to copy log files from an existing `source` S3 bucket.

```hcl
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

# This must be updated to reference an existing S3 bucket that is receiving logs
# from your application load balancer.
data "aws_s3_bucket" "source" {
  bucket = "source-bucket-name"
}

# The value in this secret must be a string literal that is the Ghost API key 
# that can be created in your account by navigating to https://app.ghostsecurity.com/settings/apikeys
data "aws_secretsmanager_secret" "ghost_api_key" {
  name = "dev/ghost-api-key"
}

# Deploy the Ghost log forwarder.
# Change the name to something meaningful in your organization.
module "dev-alb-forwarder" {
  source             = "ghostsecurity/log-forwarder/ghost"
  name               = "example-forwarder"
  api_key_secret_arn = data.aws_secretsmanager_secret.ghost_api_key.arn
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
```

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.81.0 |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_s3_input_bucket"></a> [s3\_input\_bucket](#output\_s3\_input\_bucket) | The name of the input bucket |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_api_key_secret_arn"></a> [api\_key\_secret\_arn](#input\_api\_key\_secret\_arn) | ARN of a secret in AWS secrets manager that contains a Ghost API key with write:logs permissions | `string` | n/a | yes |
| <a name="input_api_url"></a> [api\_url](#input\_api\_url) | Base URL for the Ghost API | `string` | `"https://api.ghostsecurity.com"` | no |
| <a name="input_name"></a> [name](#input\_name) | The name for this log forwarder. This must be unique within your AWS account. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Map of tags to assign to all resources. By default resources are tagged with ghost:forwarder\_id and ghost:forwarder\_name. | `map(string)` | `{}` | no |

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.forwarder_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.log_converter_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.log_converter_bucket_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.log_converter_logging](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.log_converter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.log_converter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_s3_bucket.input_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.input_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_notification.input](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification) | resource |
| [aws_s3_bucket_versioning.input](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy.basic_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy) | data source |
| [aws_iam_policy_document.forwarder_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.lambda_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_secretsmanager_secret.api_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
<!-- END_TF_DOCS -->
