resource "aws_ssm_parameter" "tfnsw_api_key" {
  name  = "/${var.project}/${var.environment}/tfnsw/api-key"
  type  = "SecureString"
  value = "placeholder"

  lifecycle {
    ignore_changes = [value]
  }
}