# Pivot-Style Filterable Reporting

OpenSearch Dashboards can produce pivot-like, filterable reporting with built-in visualization tools. This project now creates a default `Logging Pivot Reports` dashboard as part of `./scripts/up.sh` and `./scripts/apply-dashboards.sh`.

Default project behavior:

- `scripts/apply-dashboards.sh` creates data views, saved searches, `Logging Observability Overview`, and `Logging Pivot Reports`.
- Saved searches are good for triage lists and filtered log review.
- The default pivot dashboard uses metric, pie, area, heatmap, Data Table, Controls, and saved-search panels.
- Additional pivot-like summaries can be created as Data Table, TSVB Data Table, VisBuilder Data Table, or Vega visualizations, then added to dashboards with Controls.

OpenSearch documentation references:

- [Building data visualizations](https://docs.opensearch.org/latest/dashboards/visualize/viz-index/)
- [OpenSearch Dashboards overview](https://docs.opensearch.org/latest/dashboards/)

## What Is Created by Default

The default Dockerized deployment creates `Logging Pivot Reports` with these panels:

Top overview:

- `Total Logs`: valid log count in the selected time range.
- `Errors and Fatals`: count of `error` and `fatal` records.
- `Invalid Logs`: count of records routed to `logs-invalid-*`.
- `Logs With Diagnostics`: count of logs that include `diagnostic_ref`.
- `Logs by Severity`: donut chart by normalized severity.
- `Logs by Intake Source`: donut chart by HTTP, TCP, syslog, or file-tail source.

Filters and trends:

- `Pivot Dashboard Filters`: compact controls for environment, service, module, component, severity, event type, intake source, connector, and cron job.
- `Log Volume Over Time by Severity`: stacked trend for total log flow.
- `Errors Over Time by Service`: stacked trend for error/fatal records.
- `Service x Severity Heatmap`: service/severity concentration.
- `Module x Severity Heatmap`: module/severity concentration.

Pivot tables:

- `Service Health Pivot`: `service`, `module`, `component`, and `severity`.
- `Severity Breakdown Pivot`: `severity` by `service`.
- `Event Type Pivot`: `event_type`, `service`, and `module`.
- `Source Intake Pivot`: `ingest_source`, `source_system`, and `service`.
- `Connector Monitoring Pivot`: `connector_name`, `source_system`, `target_system`, `service`, and `severity`, with max `retry_count`.
- `Cron Monitoring Pivot`: `cron_name`, `service`, `event_type`, and `severity`.
- `Business Investigation Pivot`: `order_number`, `sku`, `http_status`, `service`, and `severity`.
- `Diagnostics Pivot`: `service`, `module`, and `diagnostic_ref`, with total and average diagnostic bytes.
- `Invalid Log Quality Pivot`: `invalid_reason` and `ingest_source`.

Drill-down tables:

- `Pivot Drilldown - Recent Errors and Fatals`.
- `Pivot Drilldown - Recent Diagnostics`.
- `Pivot Drilldown - Recent Invalid Logs`.

Open:

```text
http://localhost:5601/app/dashboards#/view/logging-pivot-reports
```

These panels support:

- Group logs by fields such as `service`, `module`, `severity`, `connector_name`, or `cron_name`.
- Count logs per group.
- Add dashboard filters for fields such as `environment`, `service`, `severity`, `event_type`, and `connector_name`.
- Review summary metrics, pie charts, time trends, and heatmaps before drilling into raw records.
- Use time filters to narrow reports.
- Add several table reports to one dashboard.
- Add charts beside tables for visual summaries.

## What Is Still Not Native

- A drag-and-drop Excel-style pivot table with arbitrary row, column, and measure rearrangement.
- A prebuilt matrix with dynamic column expansion for every field combination.

If you need another durable pivot-like report, build it in Dashboards first, export the saved object, then encode it in `scripts/apply-dashboards.sh` after the design is stable.

## Recommended Pivot-Like Reports

| Report | Rows | Metric | Filters |
| --- | --- | --- | --- |
| Errors by service and severity | `service`, `severity` | Count | `environment`, time range |
| Errors by module and component | `module`, `component`, `severity` | Count | `service`, time range |
| Connector failures | `connector_name`, `source_system`, `target_system` | Count, max `retry_count` | `severity`, time range |
| Cron failures | `cron_name`, `event_type`, `severity` | Count | `service`, time range |
| Business failures | `service`, `event_type`, `http_status` | Count | `order_number`, `sku`, time range |
| Diagnostic volume | `service`, `module`, `severity` | Count, sum `diagnostic_size_bytes` | `diagnostic_ref:*`, time range |
| Invalid logs | `invalid_reason`, `ingest_source` | Count | time range |

## Field Requirements

Pivot-like tables work best with mapped fields that are filterable and aggregatable.

Use these field types:

- `keyword` for row/filter fields: `service`, `module`, `component`, `severity`, `event_type`, `trace_id`, `connector_name`, `cron_name`, `source_system`, `target_system`, `order_number`, `sku`, `diagnostic_ref`.
- Numeric fields for metrics: `retry_count`, `http_status`, `diagnostic_size_bytes`.
- `date` for `@timestamp`.
- Avoid using `message` as a pivot field because it is long free text.

If a new field must appear in a pivot-style report, add it to:

1. [04-logging-contract-and-fields.md](04-logging-contract-and-fields.md).
2. `opensearch/index-template.json` when it needs a stable filter/sort/aggregation mapping.
3. `scripts/apply-dashboards.sh` if it becomes part of a durable saved object.

## Create a Data Table Pivot-Like Report

Use this for a grouped table such as "errors by service and severity".

1. Open `http://localhost:5601`.
2. Go to `Visualize`.
3. Create a new visualization.
4. Choose `Data Table`.
5. Choose the `logs-local-*` data view.
6. Set the time range, for example `Last 24 hours`.
7. Add a metric:
   - Aggregation: `Count`.
   - Label: `Log count`.
8. Add bucket rows:
   - First row bucket: `Terms` on `service`, size `10`.
   - Second row bucket: `Terms` on `severity`, size `5`.
   - Optional third row bucket: `Terms` on `module`, size `10`.
9. Add a query filter:
   ```text
   severity: (warn or error or fatal)
   ```
10. Save the visualization as `Pivot - Errors by Service and Severity`.
11. Add it to a dashboard.

This produces a pivot-like table because each row is grouped by dimensions and the metric is aggregated.

## Add Dashboard Controls

Use Controls when users need to filter the table without editing the query.

Recommended controls:

- Options list for `environment`.
- Options list for `service`.
- Options list for `module`.
- Options list for `severity`.
- Options list for `event_type`.
- Options list for `connector_name`.
- Options list for `cron_name`.
- Range slider for `diagnostic_size_bytes`.

Suggested workflow:

1. Open the dashboard.
2. Add a new panel.
3. Choose `Controls`.
4. Add an options list for a keyword field such as `service`.
5. Repeat for `severity`, `environment`, and whichever field the report depends on.
6. Save the dashboard.

Controls filter all compatible panels on the dashboard, including data tables and saved searches.

## Connector Failure Pivot Example

Sample log:

```json
{
  "@timestamp": "2026-05-19T10:00:00Z",
  "environment": "prod",
  "service": "catalog-sync",
  "module": "connector",
  "component": "shopify-import",
  "severity": "error",
  "event_type": "connector_failure",
  "message": "Connector failed after retries",
  "trace_id": "trace-connector-001",
  "connector_name": "shopify",
  "source_system": "shopify",
  "target_system": "erp",
  "retry_count": 3,
  "error_type": "timeout"
}
```

Table setup:

- Query:
  ```text
  connector_name:* and severity: (warn or error or fatal)
  ```
- Rows:
  - `connector_name`
  - `source_system`
  - `target_system`
  - `severity`
- Metrics:
  - Count
  - Max `retry_count`
- Controls:
  - `environment`
  - `connector_name`
  - `target_system`
  - `severity`

## Cron Failure Pivot Example

Sample log:

```json
{
  "@timestamp": "2026-05-19T10:05:00Z",
  "environment": "prod",
  "service": "billing",
  "module": "cron",
  "component": "invoice-close",
  "severity": "fatal",
  "event_type": "cron_failed",
  "message": "Nightly invoice close failed",
  "trace_id": "trace-cron-001",
  "cron_name": "nightly-invoice-close",
  "error_type": "database_lock"
}
```

Table setup:

- Query:
  ```text
  cron_name:* and severity: (warn or error or fatal)
  ```
- Rows:
  - `cron_name`
  - `event_type`
  - `severity`
  - `service`
- Metrics:
  - Count
- Controls:
  - `environment`
  - `service`
  - `cron_name`
  - `severity`

## Business Investigation Pivot Example

Sample log:

```json
{
  "@timestamp": "2026-05-19T10:10:00Z",
  "environment": "prod",
  "service": "checkout",
  "module": "api",
  "component": "order-submit",
  "severity": "error",
  "event_type": "order_submit_failed",
  "message": "Order submission failed",
  "trace_id": "trace-order-001",
  "order_number": "ORD-1001",
  "sku": "SKU-123",
  "http_status": 502
}
```

Table setup:

- Query:
  ```text
  order_number:* or sku:*
  ```
- Rows:
  - `service`
  - `event_type`
  - `http_status`
  - `severity`
- Metrics:
  - Count
- Controls:
  - `environment`
  - `service`
  - `sku`
  - `http_status`

## Diagnostic Pivot Example

Sample log:

```json
{
  "@timestamp": "2026-05-19T10:15:00Z",
  "environment": "prod",
  "service": "checkout",
  "module": "api",
  "component": "payment",
  "severity": "error",
  "event_type": "payment_diagnostic",
  "message": "Payment diagnostic captured",
  "trace_id": "trace-diagnostic-001",
  "diagnostic_ref": "s3://diagnostics-local/diagnostics/payment-001.json.gz",
  "diagnostic_size_bytes": 1048576
}
```

Table setup:

- Query:
  ```text
  diagnostic_ref:*
  ```
- Rows:
  - `service`
  - `module`
  - `severity`
- Metrics:
  - Count
  - Sum `diagnostic_size_bytes`
  - Average `diagnostic_size_bytes`
- Controls:
  - `environment`
  - `service`
  - `severity`

## Query Workbench Alternatives

Use Query Workbench when you want a tabular aggregation quickly and do not need a saved dashboard panel yet.

Example SQL:

```sql
SELECT service, module, severity, COUNT(*) AS log_count
FROM `logs-local-*`
WHERE severity IN ('warn', 'error', 'fatal')
GROUP BY service, module, severity
ORDER BY log_count DESC
LIMIT 100;
```

Example PPL:

```text
source=`logs-local-*` | where severity in ('warn', 'error', 'fatal') | stats count() by service, module, severity | sort -count
```

If the query becomes operationally important, turn it into a dashboard visualization or encode an equivalent saved object in `scripts/apply-dashboards.sh`.

## Vega for Matrix-Style Reports

Use Vega when Data Table is not flexible enough, for example when you need a matrix-style layout with one dimension as rows and another as columns.

Use Vega only after the report definition is stable because the JSON specification is more complex to maintain than saved searches or Data Table visualizations.

Recommended Vega use cases:

- Severity by service heat map.
- Connector by target-system matrix.
- Cron by failure-type matrix.
- Diagnostic size heat map by service/module.

## Operational Rules

- Keep exploratory manual dashboard changes in the UI until the report is proven useful.
- Encode durable reports in `scripts/apply-dashboards.sh`.
- Use stable IDs for saved objects.
- Keep fields mapped as `keyword`, numeric, or `date` when they must be aggregated.
- Keep dashboard Controls aligned with the intake checklist so every integration supplies the fields users expect to filter on.
