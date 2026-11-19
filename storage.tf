# S3 holds uploaded code, the findings JSON each stage writes, and the final reports.
# The bucket is created once in the S3 console (see README): Learner Lab blocks
# s3:GetBucketObjectLockConfiguration, which the aws_s3_bucket resource reads.
# Terraform manages everything else about it.
locals {
  data_bucket     = "${local.name}-data-${local.account}"
  data_bucket_arn = "arn:aws:s3:::${local.name}-data-${local.account}"
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = local.data_bucket
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Jobs: one item per scan run.
#   status of a job   -> GetItem(customer_id, job_id)
#   a customer's jobs -> Query(customer_id), newest first (job_id starts with a timestamp)
resource "aws_dynamodb_table" "jobs" {
  name         = "${local.name}-jobs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "customer_id"
  range_key    = "job_id"

  attribute {
    name = "customer_id"
    type = "S"
  }

  attribute {
    name = "job_id"
    type = "S"
  }
}

# Targets: APIs a customer registered for pentesting.
#   look up a registered target -> GetItem(customer_id, host)
resource "aws_dynamodb_table" "targets" {
  name         = "${local.name}-targets"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "customer_id"
  range_key    = "host"

  attribute {
    name = "customer_id"
    type = "S"
  }

  attribute {
    name = "host"
    type = "S"
  }
}

# API keys: only the SHA-256 hash of each key is stored.
#   key check -> GetItem(key_hash) returns customer_id
resource "aws_dynamodb_table" "api_keys" {
  name         = "${local.name}-api-keys"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "key_hash"

  attribute {
    name = "key_hash"
    type = "S"
  }
}

resource "aws_dynamodb_table_item" "demo_key" {
  table_name = aws_dynamodb_table.api_keys.name
  hash_key   = aws_dynamodb_table.api_keys.hash_key

  item = jsonencode({
    key_hash    = { S = sha256(var.demo_api_key) }
    customer_id = { S = "cust-demo" }
    label       = { S = "demo customer key" }
  })
}

resource "aws_dynamodb_table_item" "demo_target" {
  table_name = aws_dynamodb_table.targets.name
  hash_key   = aws_dynamodb_table.targets.hash_key
  range_key  = aws_dynamodb_table.targets.range_key

  item = jsonencode({
    customer_id = { S = "cust-demo" }
    host        = { S = "test-target.scanpilot.local" }
    verified    = { BOOL = true }
  })
}
