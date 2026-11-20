"""GET /jobs and GET /jobs/{job_id}: read job status from DynamoDB.

Its own Lambda, separate from create_job, so status checks never wait behind job creation.
"""
import json
import os

import boto3
from boto3.dynamodb.conditions import Key
from botocore.config import Config

from common import JOBS, customer_from_key, respond

s3 = boto3.client("s3", config=Config(signature_version="s3v4"))
BUCKET = os.environ["BUCKET"]
FIELDS = ("job_id", "status", "mode", "target", "created_at", "updated_at",
          "failed_step", "error_name", "report_key")


def view(item, with_report_link=False):
    out = {k: item[k] for k in FIELDS if k in item}
    if "error_info" in item:
        out["error_info"] = str(item["error_info"])[:300]
    if "sast_summary" in item:
        out["sast_summary"] = json.loads(item["sast_summary"])
    if with_report_link and "report_key" in item:
        out["report_url"] = s3.generate_presigned_url(
            "get_object", Params={"Bucket": BUCKET, "Key": item["report_key"]}, ExpiresIn=900
        )
    return out


def handler(event, context):
    customer_id = customer_from_key(event)
    if not customer_id:
        return respond(401, {"error": "missing or invalid x-api-key"})

    job_id = (event.get("pathParameters") or {}).get("job_id")
    if job_id:
        # customer_id comes from the API key, so nobody can read another customer's job
        item = JOBS.get_item(Key={"customer_id": customer_id, "job_id": job_id}).get("Item")
        if not item:
            return respond(404, {"error": "job not found"})
        return respond(200, view(item, with_report_link=True))

    result = JOBS.query(
        KeyConditionExpression=Key("customer_id").eq(customer_id),
        ScanIndexForward=False,  # newest first
        Limit=20,
    )
    return respond(200, {"jobs": [view(i) for i in result.get("Items", [])]})
