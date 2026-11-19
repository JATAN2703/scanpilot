data "aws_caller_identity" "me" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name    = var.project
  account = data.aws_caller_identity.me.account_id
  azs     = slice(data.aws_availability_zones.available.names, 0, 2)

  # Learner Lab can't create IAM roles, so every service runs as the existing LabRole.
  lab_role = "arn:aws:iam::${data.aws_caller_identity.me.account_id}:role/LabRole"

  # Built from parts, not from the resource, so the Lambdas and the state machine don't depend on each other.
  state_machine_arn = "arn:aws:states:${var.region}:${data.aws_caller_identity.me.account_id}:stateMachine:${var.project}-pipeline"
}
