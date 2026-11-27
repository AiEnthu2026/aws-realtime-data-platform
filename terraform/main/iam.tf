# --- Shared ---
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# --- Producer ---
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

# --- Consumer ---
resource "aws_iam_role" "consumer" {
  name               = "${local.name_prefix}-consumer-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "consumer" {
  statement {
    sid = "ReadStream"
    actions = [
      "kinesis:DescribeStream",
      "kinesis:DescribeStreamSummary",
      "kinesis:GetRecords",
      "kinesis:GetShardIterator",
      "kinesis:ListShards",
      "kinesis:SubscribeToShard",
    ]
    resources = [aws_kinesis_stream.vehicle_positions.arn]
  }

  statement {
    sid       = "ListStreams"
    actions   = ["kinesis:ListStreams"]
    resources = ["*"]
  }

  statement {
    sid       = "WriteCurated"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.data["curated"].arn}/vehicle_positions/*"]
  }

  statement {
    sid       = "SendToDlq"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.consumer_dlq.arn]
  }

  statement {
    sid       = "WriteLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.consumer.arn}:*"]
  }
}

resource "aws_iam_role_policy" "consumer" {
  name   = "consumer-permissions"
  role   = aws_iam_role.consumer.id
  policy = data.aws_iam_policy_document.consumer.json
}

resource "aws_iam_role" "api" {
  name               = "${local.name_prefix}-api"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "api" {
  statement {
    actions   = ["athena:StartQueryExecution", "athena:GetQueryExecution", "athena:GetQueryResults", "athena:StopQueryExecution"]
    resources = [aws_athena_workgroup.rtdp.arn]
  }
  statement {
    actions = ["glue:GetDatabase", "glue:GetTable", "glue:GetPartitions"]
    resources = [
      "arn:aws:glue:${var.region}:${local.account_id}:catalog",
      aws_glue_catalog_database.rtdp.arn,
      aws_glue_catalog_table.vehicle_positions.arn,
    ]
  }
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.data["curated"].arn}/vehicle_positions/*"]
  }
  statement {
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [aws_s3_bucket.data["curated"].arn, aws_s3_bucket.data["athena-results"].arn]
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:AbortMultipartUpload"]
    resources = ["${aws_s3_bucket.data["athena-results"].arn}/*"]
  }
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.api.arn}:*"]
  }
}

resource "aws_iam_role_policy" "api" {
  name   = "${local.name_prefix}-api"
  role   = aws_iam_role.api.id
  policy = data.aws_iam_policy_document.api.json
}