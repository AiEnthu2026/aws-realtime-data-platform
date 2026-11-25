locals {
  api_name = "${local.name_prefix}-api"
}

data "archive_file" "api" {
  type        = "zip"
  source_file = "${path.module}/../../src/api/handler.py"
  output_path = "${path.module}/../../build/api.zip"
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/lambda/${local.api_name}"
  retention_in_days = 7
}

resource "aws_lambda_function" "api" {
  function_name    = local.api_name
  role             = aws_iam_role.api.arn
  runtime          = "python3.12"
  architectures    = ["x86_64"]
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.api.output_path
  source_code_hash = data.archive_file.api.output_base64sha256
  memory_size      = 256
  timeout          = 25

  environment {
    variables = {
      ATHENA_WORKGROUP = aws_athena_workgroup.rtdp.name
      GLUE_DATABASE    = aws_glue_catalog_database.rtdp.name
    }
  }

  depends_on = [aws_cloudwatch_log_group.api, aws_iam_role_policy.api]
}
