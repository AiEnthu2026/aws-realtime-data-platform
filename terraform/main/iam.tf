data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "producer" {
  name               = "${local.name_prefix}-producer-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "producer" {
  statement {
    sid       = "ReadApiKey"
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.tfnsw_api_key.arn]
  }

  statement {
    sid       = "WriteStream"
    actions   = ["kinesis:PutRecord", "kinesis:PutRecords"]
    resources = [aws_kinesis_stream.vehicle_positions.arn]
  }

  statement {
    sid       = "WriteRawFeed"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.data["raw"].arn}/vehicle_positions/*"]
  }

  statement {
    sid       = "WriteLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.producer.arn}:*"]
  }
}

resource "aws_iam_role_policy" "producer" {
  name   = "producer-permissions"
  role   = aws_iam_role.producer.id
  policy = data.aws_iam_policy_document.producer.json
}