"""Placeholder pipeline stage, used for SAST, triage, pentest and report for now.

Sam's real stages replace it one at a time. It already follows the stage contract:
read the job input, write a findings JSON to S3, return its key. It can also be
told to fail, which tests the retry, FAILED and PARTIAL paths.
"""
import json
import os
import time
from datetime import datetime, timezone

import boto3

s3 = boto3.client("s3")
targets = boto3.resource("dynamodb").Table(os.environ["TARGETS_TABLE"])


class SimulatedStageError(Exception):
    """The job asked this stage to fail (force_fail_step), for testing."""


class TargetNotVerified(Exception):
    """The pentest target isn't registered and verified for this customer."""


PLACEHOLDER = {
    "sast": [
        {"rule": "sql-injection", "file": "app.js", "line": 9, "severity": "HIGH"},
        {"rule": "hardcoded-secret", "file": "app.js", "line": 4, "severity": "MEDIUM"},
        {"rule": "missing-security-headers", "file": "app.js", "line": 6, "severity": "LOW"},
    ],
    "triage": [
        {"rule": "sql-injection", "verdict": "true_positive", "pentest_check": "sqli-basic"},
        {"rule": "hardcoded-secret", "verdict": "true_positive", "pentest_check": None},
        {"rule": "missing-security-headers", "verdict": "false_positive", "pentest_check": None},
    ],
    "pentest": [
        {"check": "sqli-basic", "endpoint": "GET /users?id=", "result": "vulnerable"},
    ],
    "report": [
        {"priority": 1, "title": "SQL injection in GET /users", "severity": "HIGH"},
        {"priority": 2, "title": "Hardcoded secret in app.js", "severity": "MEDIUM"},
    ],
}


def handler(event, context):
    stage = event["stage"]
    customer_id, job_id = event["customer_id"], event["job_id"]
    time.sleep(3)  # so each status is visible while polling

    if event.get("force_fail_step") == stage:
        raise SimulatedStageError(f"simulated {stage} failure (test run)")

    if stage == "pentest":
        # Only pentest hosts the customer registered and verified
        host = event.get("target", "")
        item = targets.get_item(Key={"customer_id": customer_id, "host": host}).get("Item")
        if not item or not item.get("verified"):
            raise TargetNotVerified(f"{host!r} is not a verified target for {customer_id}")

    output = {
        "job_id": job_id,
        "stage": stage,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "placeholder": True,
        "items": PLACEHOLDER.get(stage, []),
    }
    folder = "reports" if stage == "report" else "findings"
    key = f"{folder}/{customer_id}/{job_id}/{stage}.json"
    s3.put_object(
        Bucket=event["bucket"],
        Key=key,
        Body=json.dumps(output, indent=2).encode(),
        ContentType="application/json",
    )
    return {"stage": stage, "output_key": key}
