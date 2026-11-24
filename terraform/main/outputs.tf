output "bucket_names" {
  value = { for k, b in aws_s3_bucket.data : k => b.bucket }
}

output "stream_name" {
  value = aws_kinesis_stream.vehicle_positions.name
}

output "tfnsw_api_key_param" {
  value = aws_ssm_parameter.tfnsw_api_key.name
}