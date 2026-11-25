output "bucket_names" {
  value = { for k, b in aws_s3_bucket.data : k => b.bucket }
}

output "stream_name" {
  value = aws_kinesis_stream.vehicle_positions.name
}

output "tfnsw_api_key_param" {
  value = aws_ssm_parameter.tfnsw_api_key.name
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.api.id
}

output "api_client_id" {
  value = aws_cognito_user_pool_client.api_client.id
}

output "cognito_token_url" {
  value = "https://${aws_cognito_user_pool_domain.api.domain}.auth.${var.region}.amazoncognito.com/oauth2/token"
}

output "api_url" {
  value = aws_apigatewayv2_stage.default.invoke_url
}