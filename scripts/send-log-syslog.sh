#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=scripts/common.sh
. scripts/common.sh
load_env

host="${VECTOR_SYSLOG_HOST:-localhost}"
port="${VECTOR_SYSLOG_PORT:-5514}"
trace_id="${1:-trace-syslog-$(date +%s)}"

payload=$(printf '{"@timestamp":"%s","environment":"local","service":"inventory","module":"connector","component":"syslog-test","severity":"error","event_type":"syslog_test","message":"Syslog ingestion test log","trace_id":"%s","connector_name":"inventory-feed","source_system":"manual-script"}' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${trace_id}")

if command -v logger >/dev/null 2>&1; then
  logger -n "${host}" -P "${port}" -T -- "${payload}" || printf '<14>1 %s localhost ingestion-platform - - - %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${payload}" | nc -w 2 "${host}" "${port}"
else
  printf '<14>1 %s localhost ingestion-platform - - - %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${payload}" | nc -w 2 "${host}" "${port}"
fi

echo "sent trace_id=${trace_id}"

