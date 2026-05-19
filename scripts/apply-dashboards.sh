#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=scripts/common.sh
. scripts/common.sh
load_env

dashboards="http://localhost:${OPENSEARCH_DASHBOARDS_PORT:-5601}"

wait_for_http "${dashboards}/api/status" "OpenSearch Dashboards" 180

python3 - "${dashboards}" <<'PY'
import json
import sys
import urllib.error
import urllib.request

dashboards = sys.argv[1].rstrip("/")


def api_post(kind, object_id, payload):
    url = f"{dashboards}/api/saved_objects/{kind}/{object_id}?overwrite=true"
    body = json.dumps(payload, separators=(",", ":")).encode()
    request = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={
            "osd-xsrf": "true",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            response.read()
    except urllib.error.HTTPError as exc:
        details = exc.read().decode(errors="replace")
        raise SystemExit(f"Failed to save {kind}/{object_id}: HTTP {exc.code}: {details}") from exc


def api_delete(kind, object_id):
    url = f"{dashboards}/api/saved_objects/{kind}/{object_id}"
    request = urllib.request.Request(url, method="DELETE", headers={"osd-xsrf": "true"})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            response.read()
    except urllib.error.HTTPError as exc:
        if exc.code != 404:
            details = exc.read().decode(errors="replace")
            raise SystemExit(f"Failed to delete {kind}/{object_id}: HTTP {exc.code}: {details}") from exc


def search_payload(title, query, index_id, columns, description=""):
    return {
        "attributes": {
            "title": title,
            "description": description,
            "columns": columns,
            "sort": [["@timestamp", "desc"]],
            "kibanaSavedObjectMeta": {
                "searchSourceJSON": json.dumps({
                    "index": index_id,
                    "query": {"language": "kuery", "query": query},
                    "filter": [],
                }, separators=(",", ":"))
            },
        },
        "references": [{
            "name": "kibanaSavedObjectMeta.searchSourceJSON.index",
            "type": "index-pattern",
            "id": index_id,
        }],
    }


def agg_metric(agg_id, agg_type="count", label=None, field=None):
    params = {}
    if label:
        params["customLabel"] = label
    if field:
        params["field"] = field
    return {
        "id": str(agg_id),
        "enabled": True,
        "type": agg_type,
        "schema": "metric",
        "params": params,
    }


def agg_terms(agg_id, field, label, schema="bucket", size=10, order_by="1", order="desc"):
    return {
        "id": str(agg_id),
        "enabled": True,
        "type": "terms",
        "schema": schema,
        "params": {
            "field": field,
            "orderBy": str(order_by),
            "order": order,
            "size": size,
            "otherBucket": False,
            "otherBucketLabel": "Other",
            "missingBucket": False,
            "missingBucketLabel": "Missing",
            "customLabel": label,
        },
    }


def agg_date_histogram(agg_id, label="Time"):
    return {
        "id": str(agg_id),
        "enabled": True,
        "type": "date_histogram",
        "schema": "segment",
        "params": {
            "field": "@timestamp",
            "useNormalizedEsInterval": True,
            "interval": "auto",
            "drop_partials": False,
            "min_doc_count": 1,
            "customLabel": label,
        },
    }


def visualization_payload(title, description, vis_type, params, aggs, index_id, query):
    return {
        "attributes": {
            "title": title,
            "description": description,
            "visState": json.dumps({
                "title": title,
                "type": vis_type,
                "params": params,
                "aggs": aggs,
            }, separators=(",", ":")),
            "uiStateJSON": "{}",
            "version": 1,
            "kibanaSavedObjectMeta": {
                "searchSourceJSON": json.dumps({
                    "index": index_id,
                    "query": {"language": "kuery", "query": query},
                    "filter": [],
                }, separators=(",", ":"))
            },
        },
        "references": [{
            "name": "kibanaSavedObjectMeta.searchSourceJSON.index",
            "type": "index-pattern",
            "id": index_id,
        }],
    }


def metric_visualization(title, description, query, index_id, metric_type="count", field=None, label=None):
    params = {
        "addTooltip": True,
        "addLegend": False,
        "type": "metric",
        "metric": {
            "percentageMode": False,
            "useRanges": False,
            "colorSchema": "Green to Red",
            "metricColorMode": "None",
            "labels": {"show": True},
        },
    }
    aggs = [agg_metric(1, metric_type, label or title, field)]
    return visualization_payload(title, description, "metric", params, aggs, index_id, query)


def pie_visualization(title, description, query, index_id, field, label):
    params = {
        "type": "pie",
        "isDonut": True,
        "addTooltip": True,
        "addLegend": True,
        "legendPosition": "right",
        "nestedLegend": False,
        "distinctColors": False,
    }
    aggs = [
        agg_metric(1, "count", "Log count"),
        agg_terms(2, field, label, schema="segment", size=10),
    ]
    return visualization_payload(title, description, "pie", params, aggs, index_id, query)


def xy_visualization(title, description, query, index_id, vis_type, split_field, split_label):
    params = {
        "type": vis_type,
        "addTooltip": True,
        "addLegend": True,
        "legendPosition": "right",
        "times": [],
        "addTimeMarker": False,
        "grid": {"categoryLines": False},
        "categoryAxes": [{
            "id": "CategoryAxis-1",
            "type": "category",
            "position": "bottom",
            "show": True,
            "style": {},
            "scale": {"type": "linear"},
            "labels": {"show": True, "truncate": 100},
            "title": {},
        }],
        "valueAxes": [{
            "id": "ValueAxis-1",
            "name": "LeftAxis-1",
            "type": "value",
            "position": "left",
            "show": True,
            "style": {},
            "scale": {"type": "linear", "mode": "normal"},
            "labels": {"show": True, "rotate": 0, "filter": False, "truncate": 100},
            "title": {"text": "Log count"},
        }],
        "seriesParams": [{
            "show": True,
            "type": vis_type,
            "mode": "stacked",
            "data": {"label": "Log count", "id": "1"},
            "valueAxis": "ValueAxis-1",
            "drawLinesBetweenPoints": True,
            "showCircles": False,
        }],
    }
    aggs = [
        agg_metric(1, "count", "Log count"),
        agg_date_histogram(2),
        agg_terms(3, split_field, split_label, schema="group", size=10),
    ]
    return visualization_payload(title, description, vis_type, params, aggs, index_id, query)


def heatmap_visualization(title, description, query, index_id, x_field, x_label, y_field, y_label):
    params = {
        "addTooltip": True,
        "addLegend": True,
        "enableHover": False,
        "legendPosition": "right",
        "times": [],
        "colorsNumber": 4,
        "colorSchema": "Reds",
        "setColorRange": False,
        "colorsRange": [],
        "invertColors": False,
        "percentageMode": False,
        "valueAxes": [{
            "show": False,
            "id": "ValueAxis-1",
            "type": "value",
            "scale": {"type": "linear", "mode": "normal"},
            "labels": {"show": False},
        }],
    }
    aggs = [
        agg_metric(1, "count", "Log count"),
        agg_terms(2, x_field, x_label, schema="segment", size=15),
        agg_terms(3, y_field, y_label, schema="group", size=10),
    ]
    return visualization_payload(title, description, "heatmap", params, aggs, index_id, query)


def table_visualization(title, description, query, index_id, buckets, metrics=None, per_page=10):
    if metrics is None:
        metrics = [{"type": "count", "label": "Log count"}]
    aggs = []
    next_id = 1
    for metric in metrics:
        aggs.append(agg_metric(next_id, metric.get("type", "count"), metric.get("label"), metric.get("field")))
        next_id += 1
    for bucket in buckets:
        aggs.append(agg_terms(
            next_id,
            bucket["field"],
            bucket.get("label", bucket["field"]),
            schema=bucket.get("schema", "bucket"),
            size=bucket.get("size", 20),
            order_by=bucket.get("orderBy", "1"),
            order=bucket.get("order", "desc"),
        ))
        next_id += 1
    params = {
        "perPage": per_page,
        "showPartialRows": False,
        "showMetricsAtAllLevels": False,
        "showTotal": False,
        "totalFunc": "sum",
        "sort": {"columnIndex": None, "direction": None},
    }
    return visualization_payload(title, description, "table", params, aggs, index_id, query)


def controls_visualization(title, description, index_id, fields):
    controls = []
    for field in fields:
        controls.append({
            "id": field["field"].replace(".", "_"),
            "fieldName": field["field"],
            "parent": "",
            "label": field.get("label", field["field"]),
            "type": "list",
            "options": {
                "type": "terms",
                "multiselect": True,
                "dynamicOptions": True,
                "size": field.get("size", 20),
                "order": "desc",
            },
            "indexPattern": index_id,
        })
    params = {
        "controls": controls,
        "updateFiltersOnChange": True,
        "useTimeFilter": True,
        "pinFilters": False,
    }
    return visualization_payload(title, description, "input_control_vis", params, [], index_id, "")


def dashboard_payload(title, description, panels, time_from="now-7d", time_to="now"):
    panel_json = []
    references = []
    for idx, panel in enumerate(panels, start=1):
        panel_ref = f"panel_{idx}"
        panel_json.append({
            "version": "2.19.1",
            "gridData": {
                "x": panel["x"],
                "y": panel["y"],
                "w": panel["w"],
                "h": panel["h"],
                "i": str(idx),
            },
            "panelIndex": str(idx),
            "embeddableConfig": {},
            "panelRefName": panel_ref,
        })
        references.append({
            "name": panel_ref,
            "type": panel["type"],
            "id": panel["id"],
        })
    return {
        "attributes": {
            "title": title,
            "description": description,
            "panelsJSON": json.dumps(panel_json, separators=(",", ":")),
            "optionsJSON": json.dumps({"useMargins": True, "hidePanelTitles": False}, separators=(",", ":")),
            "timeRestore": True,
            "timeFrom": time_from,
            "timeTo": time_to,
            "kibanaSavedObjectMeta": {
                "searchSourceJSON": json.dumps({
                    "query": {"language": "kuery", "query": ""},
                    "filter": [],
                }, separators=(",", ":"))
            },
        },
        "references": references,
    }


print("Creating OpenSearch Dashboards data views")
api_post("index-pattern", "logs-local-data-view", {"attributes": {"title": "logs-local-*", "timeFieldName": "@timestamp"}})
api_post("index-pattern", "logs-invalid-data-view", {"attributes": {"title": "logs-invalid-*", "timeFieldName": "@timestamp"}})
api_post("config", "2.19.1", {"attributes": {"defaultIndex": "logs-local-data-view", "timepicker:timeDefaults": "{\"from\":\"now-24h\",\"to\":\"now\"}"}})

common_columns = ["@timestamp", "severity", "environment", "service", "module", "component", "event_type", "message", "trace_id", "diagnostic_ref"]
error_columns = ["@timestamp", "severity", "service", "module", "component", "event_type", "message", "trace_id"]
diagnostic_columns = ["@timestamp", "severity", "service", "module", "diagnostic_ref", "diagnostic_size_bytes", "trace_id"]
invalid_columns = ["@timestamp", "invalid_reason", "ingest_source", "message", "trace_id", "raw_event"]

searches = {
    "error-overview": search_payload("Error overview", "severity: (error or fatal)", "logs-local-data-view", common_columns, "Recent error and fatal log records."),
    "errors-by-service": search_payload("Errors by service", "severity: (error or fatal)", "logs-local-data-view", common_columns, "Recent errors grouped for service triage."),
    "errors-by-module": search_payload("Errors by module", "severity: (error or fatal)", "logs-local-data-view", common_columns, "Recent errors for module/component triage."),
    "fatal-errors": search_payload("Fatal errors", "severity: fatal", "logs-local-data-view", common_columns, "Fatal records only."),
    "connector-failures": search_payload("Connector failures", "connector_name:* and severity: (warn or error or fatal)", "logs-local-data-view", common_columns, "Connector warning/error/fatal records."),
    "cron-failures": search_payload("Cron failures", "cron_name:* and severity: (warn or error or fatal)", "logs-local-data-view", common_columns, "Cron warning/error/fatal records."),
    "logs-by-trace-id": search_payload("Logs by trace_id", "trace_id:*", "logs-local-data-view", common_columns, "Trace lookup records."),
    "logs-with-diagnostic-ref": search_payload("Logs with diagnostic_ref", "diagnostic_ref:*", "logs-local-data-view", diagnostic_columns, "Logs that point to external diagnostic objects."),
    "invalid-logs": search_payload("Invalid logs", "invalid_log: true", "logs-invalid-data-view", invalid_columns, "Invalid logs with validation reasons."),
    "pivot-recent-errors": search_payload("Pivot Drilldown - Recent Errors and Fatals", "severity: (error or fatal)", "logs-local-data-view", error_columns, "Drill-down table for recent operational errors."),
    "pivot-recent-diagnostics": search_payload("Pivot Drilldown - Recent Diagnostics", "diagnostic_ref:*", "logs-local-data-view", diagnostic_columns, "Drill-down table for logs with diagnostic object references."),
    "pivot-recent-invalid": search_payload("Pivot Drilldown - Recent Invalid Logs", "invalid_log: true", "logs-invalid-data-view", invalid_columns, "Drill-down table for invalid records and raw event review."),
}
for object_id, payload in searches.items():
    api_post("search", object_id, payload)

print("Creating advanced pivot-style OpenSearch Dashboards visualizations")
visualizations = {
    "pivot-metric-total-logs": metric_visualization(
        "Total Logs",
        "Total valid logs in the selected time range.",
        "",
        "logs-local-data-view",
        label="Total logs",
    ),
    "pivot-metric-error-fatal": metric_visualization(
        "Errors and Fatals",
        "Count of error and fatal logs in the selected time range.",
        "severity: (error or fatal)",
        "logs-local-data-view",
        label="Errors and fatals",
    ),
    "pivot-metric-invalid": metric_visualization(
        "Invalid Logs",
        "Count of logs routed to the invalid index.",
        "invalid_log: true",
        "logs-invalid-data-view",
        label="Invalid logs",
    ),
    "pivot-metric-diagnostics": metric_visualization(
        "Logs With Diagnostics",
        "Count of valid logs that include diagnostic_ref.",
        "diagnostic_ref:*",
        "logs-local-data-view",
        label="Diagnostics",
    ),
    "pivot-pie-severity": pie_visualization(
        "Logs by Severity",
        "Donut chart showing log distribution by normalized severity.",
        "",
        "logs-local-data-view",
        "severity",
        "Severity",
    ),
    "pivot-pie-ingest-source": pie_visualization(
        "Logs by Intake Source",
        "Donut chart showing whether logs arrived by HTTP, TCP, syslog, or file-tail.",
        "",
        "logs-local-data-view",
        "ingest_source.keyword",
        "Intake source",
    ),
    "pivot-controls": controls_visualization(
        "Pivot Dashboard Filters",
        "Compact filter controls for common reporting dimensions.",
        "logs-local-data-view",
        [
            {"field": "environment", "label": "Environment"},
            {"field": "service", "label": "Service"},
            {"field": "module", "label": "Module"},
            {"field": "component", "label": "Component"},
            {"field": "severity", "label": "Severity"},
            {"field": "event_type", "label": "Event type"},
            {"field": "ingest_source.keyword", "label": "Intake"},
            {"field": "connector_name", "label": "Connector"},
            {"field": "cron_name", "label": "Cron job"},
        ],
    ),
    "pivot-trend-volume-severity": xy_visualization(
        "Log Volume Over Time by Severity",
        "Stacked area trend of log volume split by severity.",
        "",
        "logs-local-data-view",
        "area",
        "severity",
        "Severity",
    ),
    "pivot-trend-errors-service": xy_visualization(
        "Errors Over Time by Service",
        "Stacked area trend of error/fatal logs split by service.",
        "severity: (error or fatal)",
        "logs-local-data-view",
        "area",
        "service",
        "Service",
    ),
    "pivot-heatmap-service-severity": heatmap_visualization(
        "Service x Severity Heatmap",
        "Heatmap showing which services produce each severity.",
        "",
        "logs-local-data-view",
        "service",
        "Service",
        "severity",
        "Severity",
    ),
    "pivot-heatmap-module-severity": heatmap_visualization(
        "Module x Severity Heatmap",
        "Heatmap showing which modules produce each severity.",
        "",
        "logs-local-data-view",
        "module",
        "Module",
        "severity",
        "Severity",
    ),
    "pivot-table-service-health": table_visualization(
        "Service Health Pivot",
        "Core operational pivot by service/module/component/severity. Use this to find the noisy service path quickly.",
        "",
        "logs-local-data-view",
        [
            {"field": "service", "label": "Service", "size": 25},
            {"field": "module", "label": "Module", "size": 25},
            {"field": "component", "label": "Component", "size": 25},
            {"field": "severity", "label": "Severity", "size": 5},
        ],
        per_page=15,
    ),
    "pivot-table-severity-breakdown": table_visualization(
        "Severity Breakdown Pivot",
        "Severity-first pivot showing which services contribute to each severity level.",
        "",
        "logs-local-data-view",
        [
            {"field": "severity", "label": "Severity", "size": 5},
            {"field": "service", "label": "Service", "size": 25},
        ],
    ),
    "pivot-table-event-type": table_visualization(
        "Event Type Pivot",
        "Event-type pivot showing the active event taxonomy by service and module.",
        "",
        "logs-local-data-view",
        [
            {"field": "event_type", "label": "Event type", "size": 30},
            {"field": "service", "label": "Service", "size": 25},
            {"field": "module", "label": "Module", "size": 25},
        ],
    ),
    "pivot-table-source-intake": table_visualization(
        "Source Intake Pivot",
        "Ingestion-source pivot showing how records enter the platform and which source systems emit them.",
        "",
        "logs-local-data-view",
        [
            {"field": "ingest_source.keyword", "label": "Intake source", "size": 10},
            {"field": "source_system", "label": "Source system", "size": 25},
            {"field": "service", "label": "Service", "size": 25},
        ],
    ),
    "pivot-table-connector-monitoring": table_visualization(
        "Connector Monitoring Pivot",
        "Connector monitoring pivot for connector failures, source/target systems, retry pressure, and severity.",
        "connector_name:*",
        "logs-local-data-view",
        [
            {"field": "connector_name", "label": "Connector", "size": 25},
            {"field": "source_system", "label": "Source system", "size": 25},
            {"field": "target_system", "label": "Target system", "size": 25},
            {"field": "service", "label": "Service", "size": 25},
            {"field": "severity", "label": "Severity", "size": 5},
        ],
        metrics=[
            {"type": "count", "label": "Connector log count"},
            {"type": "max", "field": "retry_count", "label": "Max retry count"},
        ],
    ),
    "pivot-table-cron-monitoring": table_visualization(
        "Cron Monitoring Pivot",
        "Cron monitoring pivot for scheduled job failures and fatal events.",
        "cron_name:*",
        "logs-local-data-view",
        [
            {"field": "cron_name", "label": "Cron job", "size": 25},
            {"field": "service", "label": "Service", "size": 25},
            {"field": "event_type", "label": "Event type", "size": 25},
            {"field": "severity", "label": "Severity", "size": 5},
        ],
    ),
    "pivot-table-business-investigation": table_visualization(
        "Business Investigation Pivot",
        "Business investigation pivot for order, SKU, HTTP status, and affected service.",
        "order_number:* or sku:* or http_status:*",
        "logs-local-data-view",
        [
            {"field": "order_number", "label": "Order", "size": 25},
            {"field": "sku", "label": "SKU", "size": 25},
            {"field": "http_status", "label": "HTTP status", "size": 20},
            {"field": "service", "label": "Service", "size": 25},
            {"field": "severity", "label": "Severity", "size": 5},
        ],
    ),
    "pivot-table-diagnostics": table_visualization(
        "Diagnostics Pivot",
        "Diagnostic-reference pivot for finding high-value external diagnostic objects without indexing large payloads.",
        "diagnostic_ref:*",
        "logs-local-data-view",
        [
            {"field": "service", "label": "Service", "size": 25},
            {"field": "module", "label": "Module", "size": 25},
            {"field": "diagnostic_ref", "label": "Diagnostic ref", "size": 25},
        ],
        metrics=[
            {"type": "count", "label": "Diagnostic log count"},
            {"type": "sum", "field": "diagnostic_size_bytes", "label": "Total diagnostic bytes"},
            {"type": "avg", "field": "diagnostic_size_bytes", "label": "Avg diagnostic bytes"},
        ],
        per_page=15,
    ),
    "pivot-table-invalid-quality": table_visualization(
        "Invalid Log Quality Pivot",
        "Invalid-log quality pivot for identifying validation failures by reason and intake path.",
        "invalid_log: true",
        "logs-invalid-data-view",
        [
            {"field": "invalid_reason", "label": "Invalid reason", "size": 30},
            {"field": "ingest_source.keyword", "label": "Intake source", "size": 10},
        ],
        metrics=[{"type": "count", "label": "Invalid log count"}],
        per_page=15,
    ),
}
for object_id, payload in visualizations.items():
    api_post("visualization", object_id, payload)

overview_panels = [
    {"type": "search", "id": "error-overview", "x": 0, "y": 0, "w": 24, "h": 12},
    {"type": "search", "id": "errors-by-service", "x": 24, "y": 0, "w": 24, "h": 12},
    {"type": "search", "id": "errors-by-module", "x": 0, "y": 12, "w": 24, "h": 12},
    {"type": "search", "id": "fatal-errors", "x": 24, "y": 12, "w": 24, "h": 12},
    {"type": "search", "id": "connector-failures", "x": 0, "y": 24, "w": 24, "h": 12},
    {"type": "search", "id": "cron-failures", "x": 24, "y": 24, "w": 24, "h": 12},
    {"type": "search", "id": "logs-by-trace-id", "x": 0, "y": 36, "w": 24, "h": 12},
    {"type": "search", "id": "logs-with-diagnostic-ref", "x": 24, "y": 36, "w": 24, "h": 12},
    {"type": "search", "id": "invalid-logs", "x": 0, "y": 48, "w": 48, "h": 12},
]
api_post("dashboard", "logging-observability-overview", dashboard_payload(
    "Logging Observability Overview",
    "Operational saved-object dashboard for local ingestion validation and triage.",
    overview_panels,
    time_from="now-24h",
))

pivot_panels = [
    {"type": "visualization", "id": "pivot-metric-total-logs", "x": 0, "y": 0, "w": 8, "h": 7},
    {"type": "visualization", "id": "pivot-metric-error-fatal", "x": 8, "y": 0, "w": 8, "h": 7},
    {"type": "visualization", "id": "pivot-metric-invalid", "x": 16, "y": 0, "w": 8, "h": 7},
    {"type": "visualization", "id": "pivot-metric-diagnostics", "x": 24, "y": 0, "w": 8, "h": 7},
    {"type": "visualization", "id": "pivot-pie-severity", "x": 32, "y": 0, "w": 8, "h": 7},
    {"type": "visualization", "id": "pivot-pie-ingest-source", "x": 40, "y": 0, "w": 8, "h": 7},
    {"type": "visualization", "id": "pivot-controls", "x": 0, "y": 7, "w": 48, "h": 7},
    {"type": "visualization", "id": "pivot-trend-volume-severity", "x": 0, "y": 14, "w": 24, "h": 13},
    {"type": "visualization", "id": "pivot-trend-errors-service", "x": 24, "y": 14, "w": 24, "h": 13},
    {"type": "visualization", "id": "pivot-heatmap-service-severity", "x": 0, "y": 27, "w": 24, "h": 13},
    {"type": "visualization", "id": "pivot-heatmap-module-severity", "x": 24, "y": 27, "w": 24, "h": 13},
    {"type": "visualization", "id": "pivot-table-service-health", "x": 0, "y": 40, "w": 48, "h": 16},
    {"type": "visualization", "id": "pivot-table-severity-breakdown", "x": 0, "y": 56, "w": 24, "h": 14},
    {"type": "visualization", "id": "pivot-table-event-type", "x": 24, "y": 56, "w": 24, "h": 14},
    {"type": "visualization", "id": "pivot-table-source-intake", "x": 0, "y": 70, "w": 48, "h": 14},
    {"type": "visualization", "id": "pivot-table-connector-monitoring", "x": 0, "y": 84, "w": 24, "h": 16},
    {"type": "visualization", "id": "pivot-table-cron-monitoring", "x": 24, "y": 84, "w": 24, "h": 16},
    {"type": "visualization", "id": "pivot-table-business-investigation", "x": 0, "y": 100, "w": 24, "h": 16},
    {"type": "visualization", "id": "pivot-table-diagnostics", "x": 24, "y": 100, "w": 24, "h": 16},
    {"type": "visualization", "id": "pivot-table-invalid-quality", "x": 0, "y": 116, "w": 48, "h": 16},
    {"type": "search", "id": "pivot-recent-errors", "x": 0, "y": 132, "w": 48, "h": 11},
    {"type": "search", "id": "pivot-recent-diagnostics", "x": 0, "y": 143, "w": 48, "h": 11},
    {"type": "search", "id": "pivot-recent-invalid", "x": 0, "y": 154, "w": 48, "h": 11},
]
api_post("dashboard", "logging-pivot-reports", dashboard_payload(
    "Logging Pivot Reports",
    "Default advanced reporting dashboard with summary metrics, filter controls, trends, heatmaps, pivot tables, and drill-down searches.",
    pivot_panels,
    time_from="now-7d",
))

for kind, object_id in [
    ("index-pattern", "test-api-shape"),
    ("search", "test-search-shape"),
    ("dashboard", "test-dashboard-shape"),
    ("visualization", "pivot-filter-controls"),
    ("visualization", "pivot-errors-service-severity"),
    ("visualization", "pivot-errors-module-component"),
    ("visualization", "pivot-connector-failures"),
    ("visualization", "pivot-cron-failures"),
    ("visualization", "pivot-business-failures"),
    ("visualization", "pivot-diagnostic-volume"),
    ("visualization", "pivot-invalid-logs"),
]:
    api_delete(kind, object_id)

print("OpenSearch Dashboards saved objects applied")
PY
