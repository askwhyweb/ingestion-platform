#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=scripts/common.sh
. scripts/common.sh
load_env

diag_id="${1:-diag-$(date +%s)}"
bucket="${DIAGNOSTICS_BUCKET:-diagnostics-local}"
object="diagnostics/${diag_id}.json.gz"
mkdir -p .tmp/diagnostics
tmp_dir="$(mktemp -d -p "$(pwd)/.tmp/diagnostics")"
trap 'rm -rf "${tmp_dir}"' EXIT

python3 - <<PY > "${tmp_dir}/${diag_id}.json"
import json
payload = {
    "diagnostic_id": "${diag_id}",
    "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "details": "x" * (1024 * 1024)
}
print(json.dumps(payload))
PY
gzip -9 "${tmp_dir}/${diag_id}.json"

compose="$(compose_cmd)"
copy_source="${tmp_dir}/${diag_id}.json.gz"
if [[ "${compose}" == docker.exe* ]] && command -v wslpath >/dev/null 2>&1; then
  copy_source="$(wslpath -w "${copy_source}")"
fi
${compose} exec -T minio sh -c "mkdir -p /tmp/diagnostics"
${compose} cp "${copy_source}" "minio:/tmp/diagnostics/${diag_id}.json.gz"
${compose} exec -T minio sh -c "mc alias set local http://localhost:9000 '${MINIO_ROOT_USER:-minioadmin}' '${MINIO_ROOT_PASSWORD:-minioadmin123}' >/dev/null && mc cp '/tmp/diagnostics/${diag_id}.json.gz' 'local/${bucket}/${object}'"

size_bytes="$(wc -c < "${tmp_dir}/${diag_id}.json.gz" | tr -d ' ')"
trace_id="trace-diagnostic-${diag_id}"
diagnostic_ref="s3://${bucket}/${object}"

payload=$(printf '{"@timestamp":"%s","environment":"local","service":"checkout","module":"api","component":"diagnostic-test","severity":"error","event_type":"diagnostic_test","message":"Diagnostic reference test log","trace_id":"%s","diagnostic_ref":"%s","diagnostic_size_bytes":%s,"source_system":"manual-script"}' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${trace_id}" "${diagnostic_ref}" "${size_bytes}")
curl -fsS -X POST "http://localhost:${VECTOR_HTTP_PORT:-8080}/logs" \
  -H "Authorization: Bearer ${VECTOR_HTTP_TOKEN:-change-me-local-token}" \
  -H "Content-Type: application/json" \
  -d "${payload}" >/dev/null

echo "stored ${diagnostic_ref}"
echo "sent trace_id=${trace_id}"
