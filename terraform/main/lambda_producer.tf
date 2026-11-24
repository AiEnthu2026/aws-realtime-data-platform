locals {
  producer_name = "${local.name_prefix}-producer"
}

data "archive_file" "producer" {
  type        = "zip"
  source_dir  = "${path.module}/../../build/producer"
  output_path = "${path.module}/../../build/producer.zip"
}

resource "aws_cloudwatch_log_group" "producer" {
  name              = "/aws/lambda/${local.producer_name}"
  retention_in_days = 7
}

resource "aws_lambda_function" "producer" {
  function_name    = local.producer_name
  role             = aws_iam_role.producer.arn
  runtime          = "python3.12"
  architectures    = ["x86_64"]
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.producer.output_path
  source_code_hash = data.archive_file.producer.output_base64sha256
  memory_size      = 256
  timeout          = 55

  environment {
    variables = {
      FEED_URL      = "https://api.transport.nsw.gov.au/v1/gtfs/vehiclepos/buses"
      STREAM_NAME   = aws_kinesis_stream.vehicle_positions.name
      RAW_BUCKET    = aws_s3_bucket.data["raw"].bucket
      API_KEY_PARAM = aws_ssm_parameter.tfnsw_api_key.name
    }
  }

  depends_on = [aws_cloudwatch_log_group.producer, aws_iam_role_policy.producer]
}