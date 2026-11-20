# One Step Functions run per job. Each step writes its status to DynamoDB,
# retries with backoff, and a step that keeps failing marks the job FAILED.
resource "aws_sfn_state_machine" "pipeline" {
  name     = "${local.name}-pipeline"
  role_arn = local.lab_role

  definition = templatefile("${path.module}/statemachine.asl.json", {
    jobs_table = aws_dynamodb_table.jobs.name
    stage_fn   = aws_lambda_function.fn["stage_stub"].arn
    sast_fn    = aws_lambda_function.sast.arn
  })
}

# Alerts: any failed run sets off the alarm, which emails through SNS.
resource "aws_sns_topic" "alerts" {
  name = "${local.name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "failed_runs" {
  alarm_name          = "${local.name}-failed-runs"
  alarm_description   = "A ScanPilot pipeline run failed"
  namespace           = "AWS/States"
  metric_name         = "ExecutionsFailed"
  dimensions          = { StateMachineArn = aws_sfn_state_machine.pipeline.arn }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
