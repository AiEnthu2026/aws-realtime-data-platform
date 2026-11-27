locals {
  consumer_name = "${local.name_prefix}-consumer"
}

data "archive_file" "consumer" {
  type        = "zip"
  source_file = "${path.module}/../../src/consumer/handler.py"
  output_path = "${path.module}/../../build/consumer.zip"
}

resource "aws_cloudwatch_log_group" "consumer" {
  name              = "/aws/lambda/${local.consumer_name}"
  retention_in_days = 7
}

resource "aws_lambda_function" "consumer" {
  function_name    = local.consumer_name
  role             = aws_iam_role.consumer.arn
  runtime          = "python3.12"
  architectures    = ["x86_64"]
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.consumer.output_path
  source_code_hash = data.archive_file.consumer.output_base64sha256
  memory_size      = 1024
  timeout          = 120
  layers           = [var.aws_sdk_pandas_layer_arn]

  environment {
    variables = {
      CURATED_BUCKET = aws_s3_bucket.data["curated"].bucket
    }
  }

  depends_on = [aws_cloudwatch_log_group.consumer, aws_iam_role_policy.consumer]
}

resource "aws_lambda_event_source_mapping" "consumer" {
  event_source_arn                   = aws_kinesis_stream.vehicle_positions.arn
  function_name                      = aws_lambda_function.consumer.arn
  starting_position                  = "LATEST"
  batch_size                         = 5000
  maximum_batching_window_in_seconds = 60
  bisect_batch_on_function_error     = true
  maximum_retry_attempts             = 3
  maximum_record_age_in_seconds      = 3600
  function_response_types            = ["ReportBatchItemFailures"]

  destination_config {
    on_failure {
      destination_arn = aws_sqs_queue.consumer_dlq.arn
    }
  }
}