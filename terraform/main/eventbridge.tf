resource "aws_cloudwatch_event_rule" "producer_schedule" {
  name                = "${local.producer_name}-every-minute"
  schedule_expression = "rate(1 minute)"
  state               = var.producer_schedule_enabled ? "ENABLED" : "DISABLED"
}

resource "aws_cloudwatch_event_target" "producer" {
  rule = aws_cloudwatch_event_rule.producer_schedule.name
  arn  = aws_lambda_function.producer.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.producer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.producer_schedule.arn
}