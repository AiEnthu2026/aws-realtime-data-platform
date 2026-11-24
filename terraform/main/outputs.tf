output "bucket_names" {
  value = { for k, b in aws_s3_bucket.data : k => b.bucket }
}

output "stream_name" {
  value = aws_kinesis_stream.vehicle_positions.name
}