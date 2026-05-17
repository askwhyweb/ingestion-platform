#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=scripts/common.sh
. scripts/common.sh
load_env

opensearch="http://localhost:${OPENSEARCH_PORT:-9200}"
minio_user="${MINIO_ROOT_USER:-minioadmin}"
minio_pass="${MINIO_ROOT_PASSWORD:-minioadmin123}"
logs_bucket="${LOGS_ARCHIVE_BUCKET:-logs-archive-local}"
invalid_bucket="${INVALID_LOGS_BUCKET:-invalid-logs-local}"
diagnostics_bucket="${DIAGNOSTICS_BUCKET:-diagnostics-local}"

compose="$(compose_cmd)"

wait_for_trace() {
  local trace_id="$1"
  local index="$2"
  local timeout="${3:-90}"
  local start
  start="$(date +%s)"
  while true; do
    count=$(curl -fsS "${opensearch}/${index}/_count" -H 'Content-Type: application/json' -d '{"query":{"term":{"trace_id":"'"${trace_id}"'"}}}' | sed -n 's/.*"count":\([0-9][0-9]*\).*/\1/p')
    if [ "${count:-0}" -gt 0 ]; then
      echo "found trace_id=${trace_id} in ${index}"
      return 0
    fi
    if [ $(( "$(date +%s)" - start )) -ge "${timeout}" ]; then
      echo "Timed out waiting for trace_id=${trace_id} in ${index}" >&2
      return 1
    fi
    sleep 2
  done
}

wait_for_minio_objects() {
  local bucket="$1"
  local label="$2"
  local timeout="${3:-90}"
  local start
  start="$(date +%s)"
  while true; do
    if ${compose} exec -T minio sh -c "mc alias set local http://localhost:9000 '${minio_user}' '${minio_pass}' >/dev/null && mc find 'local/${bucket}' --maxdepth 5 | head -1" | grep -q .; then
      echo "found MinIO objects in ${label}"
      return 0
    fi
    if [ $(( "$(date +%s)" - start )) -ge "${timeout}" ]; then
      echo "Timed out waiting for MinIO objects in ${label}" >&2
      return 1
    fi
    sleep 2
  done
}

http_trace="trace-http-test-$(date +%s)"
tcp_trace="trace-tcp-test-$(date +%s)"
syslog_trace="trace-syslog-test-$(date +%s)"
file_trace="trace-file-test-$(date +%s)"
invalid_trace="trace-invalid-test-$(date +%s)"

bash scripts/send-log-http.sh "${http_trace}"
bash scripts/send-log-tcp.sh "${tcp_trace}"
bash scripts/send-log-syslog.sh "${syslog_trace}"

printf '{"@timestamp":"%s","environment":"local","service":"file-service","module":"file-module","component":"file-tail-test","severity":"debug","event_type":"file_test","message":"File tail ingestion test log","trace_id":"%s","source_system":"manual-script"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${file_trace}" > "logs/incoming/test-${file_trace}.jsonl"

curl -fsS -X POST "http://localhost:${VECTOR_HTTP_PORT:-8080}/logs" \
  -H "Authorization: Bearer ${VECTOR_HTTP_TOKEN:-change-me-local-token}" \
  -H "Content-Type: application/json" \
  -d '{"message":"invalid missing required fields","trace_id":"'"${invalid_trace}"'"}' >/dev/null

wait_for_trace "${http_trace}" "logs-local-*"
wait_for_trace "${tcp_trace}" "logs-local-*"
wait_for_trace "${syslog_trace}" "logs-local-*"
wait_for_trace "${file_trace}" "logs-local-*"
wait_for_trace "${invalid_trace}" "logs-invalid-*"

diag_output="$(bash scripts/generate-diagnostic.sh "test-$(date +%s)")"
echo "${diag_output}"
diag_trace="$(printf '%s\n' "${diag_output}" | sed -n 's/sent trace_id=//p')"
wait_for_trace "${diag_trace}" "logs-local-*"

wait_for_minio_objects "${logs_bucket}" "valid archive"
wait_for_minio_objects "${invalid_bucket}" "invalid archive"
wait_for_minio_objects "${diagnostics_bucket}" "diagnostics"

echo "Pipeline test passed"

