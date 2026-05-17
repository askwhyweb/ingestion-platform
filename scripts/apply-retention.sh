#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=scripts/common.sh
. scripts/common.sh
load_env

opensearch="http://localhost:${OPENSEARCH_PORT:-9200}"
logs_retention_days="${OPENSEARCH_LOGS_RETENTION_DAYS:-14}"
invalid_retention_days="${OPENSEARCH_INVALID_RETENTION_DAYS:-7}"

case "${logs_retention_days}" in
  ''|*[!0-9]*) echo "OPENSEARCH_LOGS_RETENTION_DAYS must be a positive integer" >&2; exit 2 ;;
esac
case "${invalid_retention_days}" in
  ''|*[!0-9]*) echo "OPENSEARCH_INVALID_RETENTION_DAYS must be a positive integer" >&2; exit 2 ;;
esac

mkdir -p .tmp/retention
local_policy=".tmp/retention/ism-policy-logs-local.json"
invalid_policy=".tmp/retention/ism-policy-logs-invalid.json"
sed "s/\"min_index_age\": \"14d\"/\"min_index_age\": \"${logs_retention_days}d\"/" \
  opensearch/ism-policy-logs-local.json > "${local_policy}"
sed "s/\"min_index_age\": \"7d\"/\"min_index_age\": \"${invalid_retention_days}d\"/" \
  opensearch/ism-policy-logs-invalid.json > "${invalid_policy}"

wait_for_http "${opensearch}/_cluster/health" "OpenSearch" 180

put_policy() {
  local policy_id="$1"
  local file="$2"
  curl -fsS -X DELETE "${opensearch}/_plugins/_ism/policies/${policy_id}" >/dev/null 2>&1 || true
  curl -fsS -X PUT "${opensearch}/_plugins/_ism/policies/${policy_id}" \
    -H 'Content-Type: application/json' \
    --data-binary @"${file}" >/dev/null
}

echo "Applying OpenSearch ISM retention policies"
put_policy "logs-local-retention-policy" "${local_policy}"
put_policy "logs-invalid-retention-policy" "${invalid_policy}"

echo "Applying OpenSearch index templates"
curl -fsS -X PUT "${opensearch}/_index_template/logs-local-template" \
  -H 'Content-Type: application/json' \
  --data-binary @opensearch/index-template.json >/dev/null
curl -fsS -X PUT "${opensearch}/_index_template/logs-invalid-template" \
  -H 'Content-Type: application/json' \
  --data-binary @opensearch/index-template-invalid.json >/dev/null

echo "OpenSearch retention policies and index templates applied"
