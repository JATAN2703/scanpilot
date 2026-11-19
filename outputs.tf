output "api_url" {
  value = aws_apigatewayv2_api.api.api_endpoint
}

output "data_bucket" {
  value = local.data_bucket
}

output "jobs_table" {
  value = aws_dynamodb_table.jobs.name
}

output "state_machine" {
  value = aws_sfn_state_machine.pipeline.name
}

# For Sam's Fargate pentest task
output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "pentest_security_group_id" {
  value = aws_security_group.pentest.id
}
