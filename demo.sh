#!/usr/bin/env bash
# ScanPilot demo: create a job, upload code, watch the status change.
#   ./demo.sh                              full run, ends DONE
#   ./demo.sh full triage                  triage fails, 3 retries, ends FAILED
#   ./demo.sh full pentest                 pentest fails, ends PARTIAL
#   ./demo.sh full none evil.example.com   unverified target, ends PARTIAL
#   ./demo.sh sast_only                    SAST, triage and report only
set -euo pipefail
cd "$(dirname "$0")"

MODE="${1:-full}"
FAIL="${2:-none}"
TARGET="${3:-test-target.scanpilot.local}"
KEY="${SCANPILOT_KEY:-sp-demo-key-123}"
API="$(terraform output -raw api_url)"

field() { python3 -c "import sys, json; print(json.load(sys.stdin).get('$1', ''))"; }

echo "== 1. Create job (mode=$MODE, force_fail_step=$FAIL, target=$TARGET)"
RESP="$(curl -s -X POST "$API/jobs" -H "x-api-key: $KEY" -H "content-type: application/json" \
  -d "{\"mode\":\"$MODE\",\"force_fail_step\":\"$FAIL\",\"target\":\"$TARGET\"}")"
JOB="$(echo "$RESP" | field job_id)"
if [ -z "$JOB" ]; then echo "create failed: $RESP"; exit 1; fi
URL="$(echo "$RESP" | field upload_url)"
echo "   job_id: $JOB"

echo "== 2. Upload sample-app.zip to S3 with the pre-signed URL"
mkdir -p build
rm -f build/sample-app.zip
(cd sample-app && zip -qr ../build/sample-app.zip .)
curl -s -o /dev/null -w "   upload HTTP %{http_code}\n" -X PUT --upload-file build/sample-app.zip "$URL"

echo "== 3. Poll GET /jobs/$JOB"
LAST=""
for _ in $(seq 1 120); do
  BODY="$(curl -s "$API/jobs/$JOB" -H "x-api-key: $KEY")"
  STATUS="$(echo "$BODY" | field status)"
  if [ "$STATUS" != "$LAST" ]; then echo "   $(date +%H:%M:%S)  $STATUS"; LAST="$STATUS"; fi
  case "$STATUS" in DONE|PARTIAL|FAILED) break ;; esac
  sleep 2
done

echo "== 4. Final job record"
echo "$BODY" | python3 -m json.tool
