# ScanPilot infra (Jatan's part)

Terraform for the ScanPilot control plane: VPC, S3, DynamoDB, the Jobs API and the
Step Functions pipeline. The four stages run `src/stage_stub.py` for now, a
placeholder that follows the stage contract (findings JSON in S3) until Sam's
SAST, triage, pentest and report code plugs in.

## What it creates
- **VPC**: public subnet with NAT, 2 private subnets in 2 AZs, route tables, free S3 and DynamoDB gateway endpoints, pentest security group (outbound 80/443 only)
- **S3**: `uploads/`, `findings/`, `reports/`
- **DynamoDB**: `jobs` (customer_id + job_id), `targets` (customer_id + host), `api-keys` (SHA-256 of the key)
- **Lambda**: `create_job`, `get_status`, `start_run` (S3 trigger), `stage_stub`
- **API Gateway (HTTP)**: `POST /jobs`, `GET /jobs`, `GET /jobs/{job_id}`
- **Step Functions**: run modes, status in DynamoDB at every step, retries with backoff, FAILED and PARTIAL paths
- **CloudWatch + SNS**: alarm on failed runs, email alert
- **Bootstrap** (kept between sessions): Terraform state bucket and the ECR repo for the pentest image

All services run as `LabRole`, since Learner Lab can't create IAM roles.

## Deploy (Learner Lab, us-east-1)
1. Start the lab and paste the AWS Details credentials into `~/.aws/credentials`
2. `terraform -version` (needs 1.11 or newer)
3. Once only, in the S3 console (us-east-1, default settings), create two buckets:
   `scanpilot-tfstate-<account_id>` and `scanpilot-data-<account_id>`.
   Learner Lab blocks a read that Terraform's `aws_s3_bucket` resource needs, so the buckets are made by hand.
4. Once only: `cd bootstrap && terraform init && terraform apply`
5. `cd .. && terraform init -backend-config="bucket=scanpilot-tfstate-<account_id>"`
6. `terraform apply -var alert_email=<your email>`, then confirm the SNS email
7. `./demo.sh`

## Demo runs
| Command | Ends |
|---|---|
| `./demo.sh` | DONE |
| `./demo.sh full triage` | FAILED after 3 retries |
| `./demo.sh full pentest` | PARTIAL |
| `./demo.sh full none evil.example.com` | PARTIAL (target not verified) |
| `./demo.sh sast_only` | DONE, no pentest |

## Clean up
`terraform destroy` in this folder after every session (NAT costs money per hour).
Leave `bootstrap/` and the two buckets alone. Next session: fresh lab credentials, then `terraform apply` again.
