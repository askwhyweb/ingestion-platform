# Logging Contract and Fields

The logging contract keeps logs searchable and reportable across HTTP, TCP, syslog, file-tail, and stdout integration patterns.

## Required Fields

| Field | Type | Purpose |
| --- | --- | --- |
| `@timestamp` | date | Event time from the source system |
| `environment` | keyword | `local`, `dev`, `stage`, `prod`, or equivalent |
| `service` | keyword | Owning service/application |
| `module` | keyword | Functional area such as `api`, `worker`, `cron`, `connector` |
| `component` | keyword | Smaller unit such as endpoint, job, connector, or handler |
| `severity` | keyword | Normalized to `debug`, `info`, `warn`, `error`, `fatal` |
| `event_type` | keyword | Stable event category |
| `message` | text | Human-readable message |
| `trace_id` | keyword | Correlation ID for investigation |

Missing required fields set `invalid_log: true` and route the event to `logs-invalid-*` and `invalid-logs-local`.

## Optional Fields

| Field | Type | Use |
| --- | --- | --- |
| `error_type` | keyword | Exception or failure category |
| `order_number` | keyword | Business/order investigation |
| `sku` | keyword | Product investigation |
| `cron_name` | keyword | Scheduled job reporting |
| `connector_name` | keyword | Connector reporting |
| `retry_count` | integer | Retry and resilience monitoring |
| `http_status` | integer | HTTP/API reporting |
| `source_system` | keyword | Upstream system |
| `target_system` | keyword | Downstream system |
| `diagnostic_ref` | keyword | Object storage reference |
| `diagnostic_size_bytes` | long | Diagnostic object size |

## Severity Normalization

Canonical values:

- `debug`
- `info`
- `warn`
- `error`
- `fatal`

Common aliases such as `warning`, `err`, `critical`, `alert`, and `notice` are mapped to the closest canonical value.

## Good Minimal Payload

```json
{
  "@timestamp": "2026-05-17T10:00:00Z",
  "environment": "prod",
  "service": "checkout",
  "module": "api",
  "component": "order-submit",
  "severity": "info",
  "event_type": "order_submitted",
  "message": "Order submitted",
  "trace_id": "trace-001"
}
```

## Invalid Payload Example

```json
{
  "message": "Missing most required fields",
  "trace_id": "trace-invalid-001"
}
```

This is accepted by ingestion but routed to `logs-invalid-*` with `invalid_reason`.

## Large Diagnostics

Do not put MB-level diagnostic content into OpenSearch. Store the object separately and log:

```json
{
  "diagnostic_ref": "s3://diagnostics-local/diagnostics/payment-001.json.gz",
  "diagnostic_size_bytes": 1048576
}
```

Vector removes inline `diagnostic_payload` before indexing when practical.

## Adding Custom Fields

Use this workflow when a report needs a new field:

1. Add the field name, type, and purpose to this document.
2. Add an explicit mapping in `opensearch/index-template.json` and `opensearch/index-template-invalid.json` only when the field must be filterable, sortable, or aggregatable.
3. Use the correct type:
   - `keyword` for IDs, enums, names, tenant IDs, regions, categories.
   - `text` for long free text.
   - `integer` or `long` for counts and sizes.
   - `date` for timestamps.
   - `boolean` for true/false flags.
4. Add the field to saved search columns or queries in `scripts/apply-dashboards.sh` if it should appear in dashboards.
5. Reapply:

```bash
./scripts/apply-retention.sh
./scripts/apply-dashboards.sh
```

Existing indices keep their old mappings. New daily indices pick up new templates automatically. Reindex only if old data must support the new mapping.

## Custom Field Example: tenant_id

Use `tenant_id` for multi-tenant reporting.

Recommended mapping:

```json
"tenant_id": { "type": "keyword" }
```

Example event:

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

Dashboard query:

```text
tenant_id: acme-prod and severity: (error or fatal)
```

