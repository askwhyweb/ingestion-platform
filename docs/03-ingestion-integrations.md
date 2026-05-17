# Ingestion Integrations

All logs should follow the contract in [04-logging-contract-and-fields.md](04-logging-contract-and-fields.md). Every event should include the required fields and one useful `trace_id`.

## HTTP JSON

Use HTTP when the source application can POST structured JSON.

Endpoint:

```text
POST http://localhost:8080/logs
Authorization: Bearer change-me-local-token
Content-Type: application/json
```

Example:

```bash
curl -X POST http://localhost:8080/logs \
  -H "Authorization: Bearer change-me-local-token" \
  -H "Content-Type: application/json" \
  -d '{"@timestamp":"2026-05-17T10:00:00Z","environment":"prod","service":"checkout","module":"api","component":"order-submit","severity":"info","event_type":"order_submitted","message":"Order submitted","trace_id":"trace-http-001","order_number":"ORD-1001"}'
```

Production guidance:

- Put HTTPS in front of ingestion.
- Use a real API key or token per source system.
- Add payload size limits and rate limits at the gateway.
- Track source identity with `source_system`.

## TCP JSON Lines

Use TCP when the source can stream one event per line.

```bash
printf '%s\n' '{"@timestamp":"2026-05-17T10:00:00Z","environment":"prod","service":"orders","module":"worker","component":"shipper","severity":"warn","event_type":"shipment_retry","message":"Retrying shipment update","trace_id":"trace-tcp-001","retry_count":2}' | nc localhost 9002
```

Rules:

- Send exactly one JSON object per line.
- End every event with a newline.
- Reconnect from the sender if the TCP connection drops.

## Syslog

Use syslog for system, appliance, network, or legacy tooling.

TCP example:

```bash
logger -n localhost -P 5514 -T -- '{"@timestamp":"2026-05-17T10:00:00Z","environment":"prod","service":"inventory","module":"connector","component":"warehouse-feed","severity":"error","event_type":"connector_failure","message":"Warehouse feed failed","trace_id":"trace-syslog-001","connector_name":"warehouse"}'
```

UDP example:

```bash
printf '<14>1 2026-05-17T10:00:00Z host app - - - {"@timestamp":"2026-05-17T10:00:00Z","environment":"prod","service":"system","module":"syslog","component":"agent","severity":"info","event_type":"syslog_test","message":"Syslog JSON body","trace_id":"trace-syslog-udp-001"}\n' | nc -u -w1 localhost 5514
```

Plain syslog messages are accepted, but they are routed invalid unless the JSON body provides required fields.

## File Tail

Use file-tail for batch jobs, local files, mounted logs, or Docker JSON logs converted to JSONL.

```bash
printf '%s\n' '{"@timestamp":"2026-05-17T10:00:00Z","environment":"prod","service":"billing","module":"cron","component":"invoice-close","severity":"info","event_type":"cron_complete","message":"Invoice close completed","trace_id":"trace-file-001","cron_name":"nightly-invoice-close"}' > logs/incoming/invoice-close.jsonl
```

Rules:

- Write one JSON object per line.
- Use `logs/incoming/*.jsonl`.
- The Vector file source uses `device_and_inode` fingerprinting so new files with similar content are still read.

## Stdout Integration Patterns

Stdout is supported as a pattern, not as a separate central gateway endpoint.

Pattern 1: app stdout to Docker log file to file-tail.

- Configure the app to write structured JSON to stdout.
- Let Docker write container logs.
- Mount or ship Docker log files into a Vector agent or into `logs/incoming/*.jsonl` after conversion.

Pattern 2: pipe stdout to TCP.

```bash
your-app-that-prints-json | while IFS= read -r line; do printf '%s\n' "$line" | nc localhost 9002; done
```

Pattern 3: host or sidecar Vector agent.

- Run a lightweight Vector agent next to the application.
- Read stdout/log files locally.
- Forward to central HTTP, TCP, or syslog intake.

## Connector and Cron Examples

Connector failure:

```json
{"@timestamp":"2026-05-17T10:00:00Z","environment":"prod","service":"catalog-sync","module":"connector","component":"shopify-import","severity":"error","event_type":"connector_failure","message":"Connector failed after retries","trace_id":"trace-connector-001","connector_name":"shopify","source_system":"shopify","target_system":"erp","retry_count":3,"error_type":"timeout"}
```

Cron failure:

```json
{"@timestamp":"2026-05-17T10:05:00Z","environment":"prod","service":"billing","module":"cron","component":"invoice-close","severity":"fatal","event_type":"cron_failed","message":"Nightly invoice close failed","trace_id":"trace-cron-001","cron_name":"nightly-invoice-close","error_type":"database_lock"}
```

## Diagnostics

Large diagnostic payloads should be compressed and stored in object storage. Log only:

- `diagnostic_ref`
- `diagnostic_size_bytes`

Helper:

```bash
./scripts/generate-diagnostic.sh
```

