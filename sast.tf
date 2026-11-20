# SAST stage: the course SAST scanner (sast/scanner.js) running as a Node.js Lambda.
# Run "npm install" in sast/ before terraform apply, so adm-zip ends up in the zip.
data "archive_file" "sast" {
  type        = "zip"
  source_dir  = "${path.module}/sast"
  output_path = "${path.module}/build/sast.zip"
  excludes    = ["test/local.mjs"]
}

resource "aws_cloudwatch_log_group" "sast" {
  name              = "/aws/lambda/${local.name}-sast"
  retention_in_days = 7
}

resource "aws_lambda_function" "sast" {
  function_name    = "${local.name}-sast"
  role             = local.lab_role
  runtime          = "nodejs22.x"
  handler          = "handler.handler"
  filename         = data.archive_file.sast.output_path
  source_code_hash = data.archive_file.sast.output_base64sha256
  timeout          = 60
  memory_size      = 512

  depends_on = [aws_cloudwatch_log_group.sast]
}
