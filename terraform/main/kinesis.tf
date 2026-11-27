resource "aws_kinesis_stream" "vehicle_positions" {
  name             = "${local.name_prefix}-vehicle-positions"
  shard_count      = 1
  retention_period = 24
  encryption_type  = "KMS"
  kms_key_id       = "alias/aws/kinesis"

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }
}