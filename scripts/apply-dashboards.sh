#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=scripts/common.sh
. scripts/common.sh
load_env

dashboards="http://localhost:${OPENSEARCH_DASHBOARDS_PORT:-5601}"

wait_for_http "${dashboards}/api/status" "OpenSearch Dashboards" 180

api_post() {
  local type="$1"
  local id="$2"
  local payload="$3"
  curl -fsS -X POST "${dashboards}/api/saved_objects/${type}/${id}?overwrite=true" \
    -H 'osd-xsrf: true' \
    -H 'Content-Type: application/json' \
    -d "${payload}" >/dev/null
}

search_payload() {
  local title="$1"
  local query="$2"
  local index_id="$3"
  local columns="$4"
  printf '{"attributes":{"title":"%s","columns":%s,"sort":[["@timestamp","desc"]],"kibanaSavedObjectMeta":{"searchSourceJSON":"{\\\"index\\\":\\\"%s\\\",\\\"query\\\":{\\\"language\\\":\\\"kuery\\\",\\\"query\\\":\\\"%s\\\"},\\\"filter\\\":[]}"}},"references":[{"name":"kibanaSavedObjectMeta.searchSourceJSON.index","type":"index-pattern","id":"%s"}]}' \
    "${title}" "${columns}" "${index_id}" "${query}" "${index_id}"
}

echo "Creating OpenSearch Dashboards data views"
api_post "index-pattern" "logs-local-data-view" '{"attributes":{"title":"logs-local-*","timeFieldName":"@timestamp"}}'
api_post "index-pattern" "logs-invalid-data-view" '{"attributes":{"title":"logs-invalid-*","timeFieldName":"@timestamp"}}'
api_post "config" "2.19.1" '{"attributes":{"defaultIndex":"logs-local-data-view","timepicker:timeDefaults":"{\"from\":\"now-24h\",\"to\":\"now\"}"}}'

common_columns='["@timestamp","severity","environment","service","module","component","event_type","message","trace_id","diagnostic_ref"]'
invalid_columns='["@timestamp","invalid_reason","message","trace_id","raw_event"]'

api_post "search" "error-overview" "$(search_payload "Error overview" "severity: (error or fatal)" "logs-local-data-view" "${common_columns}")"
api_post "search" "errors-by-service" "$(search_payload "Errors by service" "severity: (error or fatal)" "logs-local-data-view" "${common_columns}")"
api_post "search" "errors-by-module" "$(search_payload "Errors by module" "severity: (error or fatal)" "logs-local-data-view" "${common_columns}")"
api_post "search" "fatal-errors" "$(search_payload "Fatal errors" "severity: fatal" "logs-local-data-view" "${common_columns}")"
api_post "search" "connector-failures" "$(search_payload "Connector failures" "connector_name:* and severity: (warn or error or fatal)" "logs-local-data-view" "${common_columns}")"
api_post "search" "cron-failures" "$(search_payload "Cron failures" "cron_name:* and severity: (warn or error or fatal)" "logs-local-data-view" "${common_columns}")"
api_post "search" "logs-by-trace-id" "$(search_payload "Logs by trace_id" "trace_id:*" "logs-local-data-view" "${common_columns}")"
api_post "search" "logs-with-diagnostic-ref" "$(search_payload "Logs with diagnostic_ref" "diagnostic_ref:*" "logs-local-data-view" "${common_columns}")"
api_post "search" "invalid-logs" "$(search_payload "Invalid logs" "invalid_log: true" "logs-invalid-data-view" "${invalid_columns}")"

dashboard_payload='{"attributes":{"title":"Logging Observability Overview","description":"Operational saved-object dashboard for local ingestion validation and triage.","panelsJSON":"[{\"version\":\"2.19.1\",\"gridData\":{\"x\":0,\"y\":0,\"w\":24,\"h\":12,\"i\":\"1\"},\"panelIndex\":\"1\",\"embeddableConfig\":{},\"panelRefName\":\"panel_1\"},{\"version\":\"2.19.1\",\"gridData\":{\"x\":24,\"y\":0,\"w\":24,\"h\":12,\"i\":\"2\"},\"panelIndex\":\"2\",\"embeddableConfig\":{},\"panelRefName\":\"panel_2\"},{\"version\":\"2.19.1\",\"gridData\":{\"x\":0,\"y\":12,\"w\":24,\"h\":12,\"i\":\"3\"},\"panelIndex\":\"3\",\"embeddableConfig\":{},\"panelRefName\":\"panel_3\"},{\"version\":\"2.19.1\",\"gridData\":{\"x\":24,\"y\":12,\"w\":24,\"h\":12,\"i\":\"4\"},\"panelIndex\":\"4\",\"embeddableConfig\":{},\"panelRefName\":\"panel_4\"},{\"version\":\"2.19.1\",\"gridData\":{\"x\":0,\"y\":24,\"w\":24,\"h\":12,\"i\":\"5\"},\"panelIndex\":\"5\",\"embeddableConfig\":{},\"panelRefName\":\"panel_5\"},{\"version\":\"2.19.1\",\"gridData\":{\"x\":24,\"y\":24,\"w\":24,\"h\":12,\"i\":\"6\"},\"panelIndex\":\"6\",\"embeddableConfig\":{},\"panelRefName\":\"panel_6\"},{\"version\":\"2.19.1\",\"gridData\":{\"x\":0,\"y\":36,\"w\":24,\"h\":12,\"i\":\"7\"},\"panelIndex\":\"7\",\"embeddableConfig\":{},\"panelRefName\":\"panel_7\"},{\"version\":\"2.19.1\",\"gridData\":{\"x\":24,\"y\":36,\"w\":24,\"h\":12,\"i\":\"8\"},\"panelIndex\":\"8\",\"embeddableConfig\":{},\"panelRefName\":\"panel_8\"},{\"version\":\"2.19.1\",\"gridData\":{\"x\":0,\"y\":48,\"w\":48,\"h\":12,\"i\":\"9\"},\"panelIndex\":\"9\",\"embeddableConfig\":{},\"panelRefName\":\"panel_9\"}]","optionsJSON":"{\"useMargins\":true,\"hidePanelTitles\":false}","timeRestore":true,"timeFrom":"now-24h","timeTo":"now","kibanaSavedObjectMeta":{"searchSourceJSON":"{\"query\":{\"language\":\"kuery\",\"query\":\"\"},\"filter\":[]}"}},"references":[{"name":"panel_1","type":"search","id":"error-overview"},{"name":"panel_2","type":"search","id":"errors-by-service"},{"name":"panel_3","type":"search","id":"errors-by-module"},{"name":"panel_4","type":"search","id":"fatal-errors"},{"name":"panel_5","type":"search","id":"connector-failures"},{"name":"panel_6","type":"search","id":"cron-failures"},{"name":"panel_7","type":"search","id":"logs-by-trace-id"},{"name":"panel_8","type":"search","id":"logs-with-diagnostic-ref"},{"name":"panel_9","type":"search","id":"invalid-logs"}]}'
api_post "dashboard" "logging-observability-overview" "${dashboard_payload}"

curl -fsS -X DELETE "${dashboards}/api/saved_objects/index-pattern/test-api-shape" -H 'osd-xsrf: true' >/dev/null 2>&1 || true
curl -fsS -X DELETE "${dashboards}/api/saved_objects/search/test-search-shape" -H 'osd-xsrf: true' >/dev/null 2>&1 || true
curl -fsS -X DELETE "${dashboards}/api/saved_objects/dashboard/test-dashboard-shape" -H 'osd-xsrf: true' >/dev/null 2>&1 || true

echo "OpenSearch Dashboards saved objects applied"
