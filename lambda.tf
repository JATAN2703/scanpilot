data "archive_file" "src" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/build/src.zip"
}

locals {
  functions = {
    create_job = "create_job.handler" # POST /jobs
    get_status = "get_status.handler" # GET /jobs and GET /jobs/{job_id}
    start_run  = "start_run.handler"  # S3 upload trigger, starts the pipeline
    stage_stub = "stage_stub.handler" # placeholder stage until the real scanners plug in
  }
}

resource "aws_cloudwatch_log_group" "fn" {
  for_each          = local.functions
  name              = "/aws/lambda/${local.name}-${each.key}"
  retention_in_days = 7
}

resource "aws_lambda_function" "fn" {
  for_each         = local.functions
  function_name    = "${local.name}-${each.key}"
  role             = local.lab_role
  runtime          = "python3.12"
  handler          = each.value
  filename         = data.archive_file.src.output_path
  source_code_hash = data.archive_file.src.output_base64sha256
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      JOBS_TABLE        = aws_dynamodb_table.jobs.name
      KEYS_TABLE        = aws_dynamodb_table.api_keys.name
      TARGETS_TABLE     = aws_dynamodb_table.targets.name
      BUCKET            = local.data_bucket
      STATE_MACHINE_ARN = local.state_machine_arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.fn]
}

# Upload finished -> start_run Lambda -> Step Functions run
resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fn["start_run"].function_name
  principal     = "s3.amazonaws.com"
  source_arn    = local.data_bucket_arn
}

resource "aws_s3_bucket_notification" "uploads" {
  bucket = local.data_bucket

  lambda_function {
    lambda_function_arn = aws_lambda_function.fn["start_run"].arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
  }

  # one change at a time on the bucket, or S3 can reject the second one
  depends_on = [aws_lambda_permission.s3_invoke, aws_s3_bucket_public_access_block.data]
}
