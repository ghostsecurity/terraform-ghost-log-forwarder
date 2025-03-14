// LogConverter: Lambda function
resource "aws_lambda_function" "log_converter" {
  function_name = "ghost-${var.name}-function"
  image_uri     = local.lambda_image
  package_type  = "Image"
  architectures = ["arm64"]
  role          = aws_iam_role.log_converter_role.arn
  timeout       = 60

  environment {
    variables = {
      GHOST_API_URL     = var.api_url
      GHOST_API_KEY_ARN = var.api_key_secret_arn
    }
  }

  tags = local.tags
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
  name                  = "ghost-${var.name}-lambda"
  assume_role_policy    = data.aws_iam_policy_document.lambda_assume_role.json
  path                  = "/"
  force_detach_policies = true

  tags = local.tags
}

// LogConverter: Assume role definition
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    effect = "Allow"
  }
}

// LogConverter: attach ability to get at the buckets
resource "aws_iam_role_policy_attachment" "log_converter_bucket_access" {
  policy_arn = aws_iam_policy.forwarder_lambda.arn
  role       = aws_iam_role.log_converter_role.name
}

// LogConverter: IAM policy
resource "aws_iam_policy" "forwarder_lambda" {
  name        = "ghost-${var.name}-access"
  description = "IAM policy for Ghost Log Forwarder to access S3 bucket and read Ghost API key secret"
  policy      = data.aws_iam_policy_document.forwarder_lambda.json
}

// LogConverter: policy for bucket access
data "aws_iam_policy_document" "forwarder_lambda" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.input_bucket.arn}/*"]
    effect    = "Allow"
  }
  statement {
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
    ]
    resources = [var.api_key_secret_arn]
    effect    = "Allow"
  }
}

// LogConverter: AWS managed policy for lambda function logging
data "aws_iam_policy" "basic_execution_role" {
  name = "AWSLambdaBasicExecutionRole"
}

// LogConverter: attach ability to create CloudWatch log groups and write logs
resource "aws_iam_role_policy_attachment" "log_converter_logging" {
  policy_arn = data.aws_iam_policy.basic_execution_role.arn
  role       = aws_iam_role.log_converter_role.name
}

// LogConverter: invoke lambda function for new objects in the input bucket
resource "aws_s3_bucket_notification" "input" {
  bucket = aws_s3_bucket.input_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.log_converter.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".gz"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.log_converter.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".log"
  }

  depends_on = [aws_lambda_permission.log_converter]
}
