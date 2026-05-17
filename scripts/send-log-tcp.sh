#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=scripts/common.sh
. scripts/common.sh
load_env

host="${VECTOR_TCP_HOST:-localhost}"
port="${VECTOR_TCP_PORT:-9002}"
trace_id="${1:-trace-tcp-$(date +%s)}"

payload=$(printf '{"@timestamp":"%s","environment":"local","service":"orders","module":"worker","component":"tcp-test","severity":"warn","event_type":"tcp_test","message":"TCP JSON lines ingestion test log","trace_id":"%s","source_system":"manual-script"}' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${trace_id}")

printf '%s\n' "${payload}" | nc -w 2 "${host}" "${port}"
echo "sent trace_id=${trace_id}"

