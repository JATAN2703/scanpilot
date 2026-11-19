"""Shared helpers for the ScanPilot Lambdas."""
import hashlib
import json
import os

import boto3

_ddb = boto3.resource("dynamodb")
JOBS = _ddb.Table(os.environ["JOBS_TABLE"])
KEYS = _ddb.Table(os.environ["KEYS_TABLE"])


def respond(status, body):
    return {
        "statusCode": status,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(body, default=str),
    }


def customer_from_key(event):
    """Return the customer_id for the x-api-key header, or None.

    Only the SHA-256 hash of each key is stored, so the table never holds real keys.
    """
    headers = {k.lower(): v for k, v in (event.get("headers") or {}).items()}
    key = headers.get("x-api-key")
    if not key:
        return None
    digest = hashlib.sha256(key.encode()).hexdigest()
    item = KEYS.get_item(Key={"key_hash": digest}).get("Item")
    return item["customer_id"] if item else None
