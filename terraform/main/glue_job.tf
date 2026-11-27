data "aws_iam_policy_document" "glue_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "glue" {
  name               = "${local.name_prefix}-glue"
  assume_role_policy = data.aws_iam_policy_document.glue_assume.json
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

data "aws_iam_policy_document" "glue" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.data["curated"].arn}/vehicle_positions/*", "${aws_s3_bucket.data["artifacts"].arn}/glue/*"]
  }
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.data["curated"].arn, aws_s3_bucket.data["gold"].arn]
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.data["gold"].arn}/*"]
  }
}

resource "aws_iam_role_policy" "glue" {
  name   = "${local.name_prefix}-glue"
  role   = aws_iam_role.glue.id
  policy = data.aws_iam_policy_document.glue.json
}

resource "aws_s3_object" "gold_hourly_script" {
  bucket = aws_s3_bucket.data["artifacts"].id
  key    = "glue/gold_hourly.py"
  source = "${path.module}/../../src/glue/gold_hourly.py"
  etag   = filemd5("${path.module}/../../src/glue/gold_hourly.py")
}

resource "aws_glue_job" "gold_hourly" {
  name              = "${local.name_prefix}-gold-hourly"
  role_arn          = aws_iam_role.glue.arn
  glue_version      = "5.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 15
  max_retries       = 0

  command {
    script_location = "s3://${aws_s3_bucket.data["artifacts"].bucket}/${aws_s3_object.gold_hourly_script.key}"
    python_version  = "3"
  }

  default_arguments = {
    "--CURATED_PATH"                     = "s3://${aws_s3_bucket.data["curated"].bucket}/vehicle_positions/"
    "--GOLD_PATH"                        = "s3://${aws_s3_bucket.data["gold"].bucket}/vehicle_activity_hourly/"
    "--LOOKBACK_DAYS"                    = "3"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
  }

  execution_property {
    max_concurrent_runs = 1
  }
}