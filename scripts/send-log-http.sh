#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=scripts/common.sh
. scripts/common.sh
load_env

url="${VECTOR_HTTP_URL:-http://localhost:${VECTOR_HTTP_PORT:-8080}/logs}"
token="${VECTOR_HTTP_TOKEN:-change-me-local-token}"
trace_id="${1:-trace-http-$(date +%s)}"

payload=$(printf '{"@timestamp":"%s","environment":"local","service":"checkout","module":"api","component":"http-test","severity":"info","event_type":"http_test","message":"HTTP ingestion test log","trace_id":"%s","source_system":"manual-script"}' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${trace_id}")

curl -fsS -X POST "${url}" \
  -H "Authorization: Bearer ${token}" \
  -H "Content-Type: application/json" \
  -d "${payload}"
echo
echo "sent trace_id=${trace_id}"

