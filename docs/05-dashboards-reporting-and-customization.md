# Dashboards, Reporting, and Customization

OpenSearch Dashboards is the human reporting layer for the platform. Dashboards are created by `scripts/apply-dashboards.sh` using the saved objects API.

## Current Saved Objects

Data views:

- `logs-local-*`
- `logs-invalid-*`

Dashboards:

- `Logging Observability Overview`
- `Logging Pivot Reports`

Saved searches:

- Error overview
- Errors by service
- Errors by module
- Fatal errors
- Connector failures
- Cron failures
- Logs by `trace_id`
- Logs with `diagnostic_ref`
- Invalid logs

Pivot-style visualizations:

- Total Logs
- Errors and Fatals
- Invalid Logs
- Logs With Diagnostics
- Logs by Severity
- Logs by Intake Source
- Pivot Dashboard Filters
- Log Volume Over Time by Severity
- Errors Over Time by Service
- Service x Severity Heatmap
- Module x Severity Heatmap
- Service Health Pivot
- Severity Breakdown Pivot
- Event Type Pivot
- Source Intake Pivot
- Connector Monitoring Pivot
- Cron Monitoring Pivot
- Business Investigation Pivot
- Diagnostics Pivot
- Invalid Log Quality Pivot

Pivot drill-down saved searches:

- Pivot Drilldown - Recent Errors and Fatals
- Pivot Drilldown - Recent Diagnostics
- Pivot Drilldown - Recent Invalid Logs

Open:

```text
http://localhost:5601/app/dashboards#/view/logging-observability-overview
http://localhost:5601/app/dashboards#/view/logging-pivot-reports
```

Reapply:

```bash
./scripts/apply-dashboards.sh
```

The default bootstrap also creates `Logging Pivot Reports`, an advanced grouped and filterable dashboard backed by metric, pie, area, heatmap, Data Table, Controls, and saved-search panels. See [12-pivot-style-filterable-reporting.md](12-pivot-style-filterable-reporting.md).

## Supported Reporting Fields

Core fields:

- `@timestamp`
- `environment`
- `service`
- `module`
- `component`
- `severity`
- `event_type`
- `trace_id`

Error and operations:

- `error_type`
- `http_status`
- `retry_count`

Business:

- `order_number`
- `sku`

Job and connector:

- `cron_name`
- `connector_name`
- `source_system`
- `target_system`

Diagnostics:

- `diagnostic_ref`
- `diagnostic_size_bytes`

Invalid logs:

- `invalid_log`
- `invalid_reason`

## How to Add a Report

Use one saved search per reporting question.

1. Decide the question, for example “Which connectors are failing?”
2. Confirm the payload has the fields needed for that question.
3. Add a saved search in `scripts/apply-dashboards.sh`.
4. Add the saved search to an existing dashboard or create a new dashboard payload.
5. Use stable object IDs, such as `connector-failures-by-target`.
6. Reapply dashboards:

```bash
./scripts/apply-dashboards.sh
```

Manual UI edits are useful for exploration. Any report that must survive reset or migration should be encoded in `scripts/apply-dashboards.sh`.

## How to Add a New Field for Reporting

1. Add the field to [04-logging-contract-and-fields.md](04-logging-contract-and-fields.md).
2. Add explicit OpenSearch mappings only when the field must be filtered, sorted, or aggregated.
3. Choose the type:
   - `keyword` for IDs, categories, names, enums.
   - `text` for long free text.
   - `integer` or `long` for counts, sizes, statuses.
   - `date` for timestamps.
   - `boolean` for flags.
4. Add the field to saved search columns in `scripts/apply-dashboards.sh`.
5. Reapply:

```bash
./scripts/apply-retention.sh
./scripts/apply-dashboards.sh
```

## Multi-Report Planning

Create separate dashboards when the audience or workflow is different. Add panels to an existing dashboard when the report supports the same workflow.

| Dashboard | Purpose | Required fields | Suggested query | Suggested columns |
| --- | --- | --- | --- | --- |
| Operations Overview | General health and triage | `severity`, `service`, `module`, `trace_id` | `severity: (error or fatal)` | `@timestamp`, `severity`, `service`, `module`, `message`, `trace_id` |
| Connector Monitoring | Connector failures and retries | `connector_name`, `source_system`, `target_system`, `retry_count` | `connector_name:* and severity: (warn or error or fatal)` | `@timestamp`, `connector_name`, `source_system`, `target_system`, `retry_count`, `message` |
| Cron Monitoring | Scheduled job failures | `cron_name`, `event_type`, `severity` | `cron_name:* and severity: (warn or error or fatal)` | `@timestamp`, `cron_name`, `event_type`, `severity`, `message`, `trace_id` |
| Business Investigations | Order/SKU investigation | `order_number`, `sku`, `trace_id`, `http_status` | `order_number:* or sku:*` | `@timestamp`, `order_number`, `sku`, `http_status`, `service`, `message`, `trace_id` |
| Diagnostic Review | Find logs with external diagnostics | `diagnostic_ref`, `diagnostic_size_bytes` | `diagnostic_ref:*` | `@timestamp`, `service`, `module`, `severity`, `diagnostic_ref`, `diagnostic_size_bytes` |
| Data Quality | Invalid/malformed log review | `invalid_log`, `invalid_reason`, `raw_event` | `invalid_log: true` | `@timestamp`, `invalid_reason`, `message`, `trace_id`, `raw_event` |

## Connector Failure Report

Purpose: show failing connectors and their upstream/downstream systems.

Example payload:

```json
{
  "@timestamp": "2026-05-17T10:00:00Z",
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

Query:

```text
connector_name:* and severity: (warn or error or fatal)
```

Suggested columns:

```text
@timestamp, severity, connector_name, source_system, target_system, retry_count, error_type, message, trace_id
```

Create a separate dashboard when connector operators need a dedicated view. Add a panel to Operations Overview when connector failures are only one part of incident triage.

## Cron Failure Report

Purpose: show failed scheduled jobs and their failure categories.

Example payload:

```json
{
  "@timestamp": "2026-05-17T10:05:00Z",
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

Query:

```text
cron_name:* and severity: (warn or error or fatal)
```

Suggested columns:

```text
@timestamp, severity, cron_name, event_type, error_type, message, trace_id
```

## Business Investigation Report

Purpose: find customer/order/product-impacting failures.

Example payload:

```json
{
  "@timestamp": "2026-05-17T10:10:00Z",
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

Query:

```text
order_number:* or sku:*
```

Suggested columns:

```text
@timestamp, severity, order_number, sku, http_status, service, component, message, trace_id
```

## Diagnostic Report

Purpose: find logs that have large external diagnostic objects.

Example payload:

```json
{
  "@timestamp": "2026-05-17T10:15:00Z",
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

Query:

```text
diagnostic_ref:*
```

Suggested columns:

```text
@timestamp, severity, service, module, component, diagnostic_ref, diagnostic_size_bytes, trace_id
```

## Tenant Report Customization

Use `tenant_id` for multi-tenant reporting.

1. Add `tenant_id` to the logging contract.
2. Map it as `keyword` in both OpenSearch templates.
3. Add it to saved search columns and queries.
4. Reapply retention and dashboards.

Example payload:

```json
{
  "@timestamp": "2026-05-17T10:20:00Z",
  "environment": "prod",
  "service": "checkout",
  "module": "api",
  "component": "order-submit",
  "severity": "error",
  "event_type": "tenant_order_error",
  "message": "Tenant order failed",
  "trace_id": "trace-tenant-001",
  "tenant_id": "acme-prod"
}
```

Query:

```text
tenant_id: acme-prod and severity: (error or fatal)
```

## Reporting by Ingestion Source

Use `ingest_source` to understand source behavior:

- `http`
- `tcp_json`
- `syslog`
- `file_tail`

Useful reports:

- Invalid logs by `ingest_source`
- High-volume sources
- Sources producing diagnostics
- Sources missing required fields
