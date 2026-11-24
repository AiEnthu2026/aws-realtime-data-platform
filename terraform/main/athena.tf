resource "aws_athena_workgroup" "rtdp" {
  name          = "${local.name_prefix}-wg"
  force_destroy = true

  configuration {
    enforce_workgroup_configuration = true
    bytes_scanned_cutoff_per_query  = 1073741824

    result_configuration {
      output_location = "s3://${aws_s3_bucket.data["athena-results"].bucket}/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
}