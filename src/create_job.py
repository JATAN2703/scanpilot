"""POST /jobs: create a scan job and return a pre-signed S3 upload URL."""
import base64
import json
import os
import uuid
from datetime import datetime, timezone

import boto3
from botocore.config import Config

from common import JOBS, customer_from_key, respond

s3 = boto3.client("s3", config=Config(signature_version="s3v4"))
BUCKET = os.environ["BUCKET"]
MODES = {"full", "sast_only", "pentest_only"}
STAGES = {"none", "sast", "triage", "pentest", "report"}  # force_fail_step, for testing failures
DEFAULT_TARGET = "test-target.scanpilot.local"


def new_job_id():
    # Starts with a UTC timestamp, so job_id sorts by time (newest-first queries)
    now = datetime.now(timezone.utc)
    return now.strftime("%Y%m%dT%H%M%S") + f"{now.microsecond // 1000:03d}-{uuid.uuid4().hex[:6]}"


def handler(event, context):
    customer_id = customer_from_key(event)
    if not customer_id:
        return respond(401, {"error": "missing or invalid x-api-key"})

    raw = event.get("body") or "{}"
    if event.get("isBase64Encoded"):
        raw = base64.b64decode(raw).decode()
    try:
        body = json.loads(raw)
    except json.JSONDecodeError:
        return respond(400, {"error": "body must be JSON"})
    if not isinstance(body, dict):
        return respond(400, {"error": "body must be a JSON object"})

    mode = body.get("mode", "full")
    if mode not in MODES:
        return respond(400, {"error": f"mode must be one of {sorted(MODES)}"})
    force_fail = body.get("force_fail_step", "none")
    if force_fail not in STAGES:
        return respond(400, {"error": f"force_fail_step must be one of {sorted(STAGES)}"})
    target = body.get("target") or DEFAULT_TARGET
    if not isinstance(target, str):
        return respond(400, {"error": "target must be a host name"})

    job_id = new_job_id()
    now = datetime.now(timezone.utc).isoformat()
    JOBS.put_item(Item={
        "customer_id": customer_id,
        "job_id": job_id,
        "status": "QUEUED",
        "mode": mode,
        "target": target,
        "force_fail_step": force_fail,
        "created_at": now,
        "updated_at": now,
    })

    key = f"uploads/{customer_id}/{job_id}/code.zip"
    upload_url = s3.generate_presigned_url(
        "put_object", Params={"Bucket": BUCKET, "Key": key}, ExpiresIn=900
    )
    return respond(201, {"job_id": job_id, "status": "QUEUED", "mode": mode, "upload_url": upload_url})
