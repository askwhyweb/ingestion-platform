#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=scripts/common.sh
. scripts/common.sh
load_env

compose="$(compose_cmd)"
echo "Using Compose command: ${compose}"
${compose} up -d

opensearch_port="${OPENSEARCH_PORT:-9200}"
wait_for_http "http://localhost:${opensearch_port}/_cluster/health" "OpenSearch" 180

bash scripts/apply-retention.sh
bash scripts/apply-dashboards.sh

echo "Stack started. OpenSearch: http://localhost:${opensearch_port}"
echo "Dashboards: http://localhost:${OPENSEARCH_DASHBOARDS_PORT:-5601}"
echo "MinIO Console: http://localhost:${MINIO_CONSOLE_PORT:-9001}"
