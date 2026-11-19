"""S3 trigger: a finished upload under uploads/ starts the Step Functions run for that job."""
import json
import os
import urllib.parse
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError

from common import JOBS

sfn = boto3.client("stepfunctions")
STATE_MACHINE_ARN = os.environ["STATE_MACHINE_ARN"]


def now():
    return datetime.now(timezone.utc).isoformat()


def handler(event, context):
    for record in event.get("Records", []):
        bucket = record["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])
        parts = key.split("/")  # uploads/<customer_id>/<job_id>/code.zip
        if len(parts) != 4 or parts[0] != "uploads":
            print(f"skip: unexpected key {key}")
            continue
        customer_id, job_id = parts[1], parts[2]
        job_key = {"customer_id": customer_id, "job_id": job_id}

        # Claim the job (QUEUED -> STARTED) so a duplicate S3 event can't start it twice
        try:
            job = JOBS.update_item(
                Key=job_key,
                UpdateExpression="SET #s = :started, updated_at = :t",
                ConditionExpression="#s = :queued",
                ExpressionAttributeNames={"#s": "status"},
                ExpressionAttributeValues={":started": "STARTED", ":queued": "QUEUED", ":t": now()},
                ReturnValues="ALL_NEW",
            )["Attributes"]
        except ClientError as err:
            if err.response["Error"]["Code"] == "ConditionalCheckFailedException":
                print(f"skip: {job_id} is missing or already started")
                continue
            raise

        run_input = {
            "customer_id": customer_id,
            "job_id": job_id,
            "bucket": bucket,
            "code_key": key,
            "mode": job.get("mode", "full"),
            "target": job.get("target", ""),
            "force_fail_step": job.get("force_fail_step", "none"),
        }
        try:
            run = sfn.start_execution(
                stateMachineArn=STATE_MACHINE_ARN, name=job_id, input=json.dumps(run_input)
            )
        except Exception as err:
            JOBS.update_item(
                Key=job_key,
                UpdateExpression="SET #s = :f, failed_step = :step, error_info = :e, updated_at = :t",
                ExpressionAttributeNames={"#s": "status"},
                ExpressionAttributeValues={":f": "FAILED", ":step": "START", ":e": str(err)[:500], ":t": now()},
            )
            raise

        JOBS.update_item(
            Key=job_key,
            UpdateExpression="SET execution_arn = :e",
            ExpressionAttributeValues={":e": run["executionArn"]},
        )
        print(f"started {run['executionArn']}")
