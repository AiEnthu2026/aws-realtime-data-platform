resource "aws_sqs_queue" "consumer_dlq" {
  name                      = "${local.name_prefix}-consumer-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}