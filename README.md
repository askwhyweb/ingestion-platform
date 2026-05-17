# Centralized Logging and Observability Ingestion Platform

A Dockerized centralized logging and observability ingestion platform licensed under the GNU Affero General Public License v3.0 (AGPLv3). It accepts structured logs from external systems over HTTP JSON, TCP JSON lines, syslog, and mounted file-tail inputs, buffers them through Kafka, processes and normalizes them with Vector, indexes searchable logs in OpenSearch, and archives logs and large diagnostics to MinIO-compatible object storage. It includes OpenSearch Dashboards saved objects, retention policies, stress-testing utilities, and production guidance for secure deployment and future GCP Cloud Storage migration.

This repository runs a local Dockerized logging platform for external systems. It accepts structured logs through HTTP, TCP, syslog, and mounted files, buffers them in Kafka, processes them with Vector, indexes searchable records in OpenSearch, and stores compressed archive/diagnostic objects in MinIO.

The platform is designed for integration testing and local operations work. It does not depend on fixed sample applications as the main log source. The stress generator is optional and runs only when you ask for it.

## What Runs

| Service | Purpose | Local URL/Port |
| --- | --- | --- |
| `vector-ingest` | HTTP, TCP, syslog, and file-tail intake | `8080`, `9002`, `5514` |
| `kafka` | Buffered log handoff and replay | `19092` for host debug |
| `vector-processor` | Validation, normalization, enrichment, routing | internal |
| `opensearch` | Searchable valid and invalid log indices | `http://localhost:9200` |
| `opensearch-dashboards` | Human search, saved searches, dashboards | `http://localhost:5601` |
| `minio` | Local object storage for archives and diagnostics | `http://localhost:9000`, console `9001` |
| `log-stress-tool` | Optional test utility | Compose `stress` profile only |

## Quick Start

```bash
cp .env.example .env
./scripts/up.sh
./scripts/test-pipeline.sh
```

`./scripts/up.sh` starts the stack, applies OpenSearch retention/index templates, and creates OpenSearch Dashboards saved objects. Scripts prefer `docker compose`, then `docker.exe compose`, then `docker-compose`.

Stop the stack:

```bash
./scripts/down.sh
```

Stop and remove volumes only when you want to reset local data:

```bash
./scripts/down.sh --volumes
```

## Validation Commands

```bash
docker compose config
bash -n scripts/*.sh kafka/init-topics.sh
sh -n minio/init-buckets.sh
./scripts/apply-retention.sh
./scripts/apply-dashboards.sh
./scripts/test-pipeline.sh
```

`./scripts/test-pipeline.sh` verifies HTTP, TCP, syslog, file-tail, invalid-log routing, diagnostic object storage, OpenSearch search, and MinIO archive paths.

## Which Integration Should I Use?

| Source type | Use when | How |
| --- | --- | --- |
| HTTP JSON | An app can POST structured events | `POST http://localhost:8080/logs` with bearer token |
| TCP JSON lines | A service can stream one JSON event per line | Send to `localhost:9002` |
| Syslog | System, network, or legacy tooling already emits syslog | Send TCP/UDP to `localhost:5514` |
| File tail | Batch jobs, mounted logs, Docker JSON log files | Write JSONL into `./logs/incoming/*.jsonl` |
| Stdout | Apps only write to stdout | Pipe stdout to TCP, tail Docker log files, or run a local Vector agent |
| Diagnostics | Large payloads must not be indexed | Store compressed object in MinIO/GCS and log `diagnostic_ref` |

Stdout is not a separate central endpoint. It is supported through integration patterns: Docker log file tailing, piping to TCP/HTTP, or a host/sidecar Vector agent.

## Send Logs

HTTP JSON requires a bearer token:

```bash
curl -X POST http://localhost:8080/logs \
  -H "Authorization: Bearer change-me-local-token" \
  -H "Content-Type: application/json" \
  -d '{"@timestamp":"2026-05-17T10:00:00Z","environment":"local","service":"checkout","module":"api","component":"orders","severity":"info","event_type":"order_created","message":"Order created","trace_id":"trace-123","order_number":"ORD-1001"}'
```

Script helpers:

```bash
./scripts/send-log-http.sh
./scripts/send-log-tcp.sh
./scripts/send-log-syslog.sh
```

File-tail input watches `./logs/incoming/*.jsonl`. Add one JSON object per line.

## Logging Contract

Required fields:

- `@timestamp`
- `environment`
- `service`
- `module`
- `component`
- `severity`
- `event_type`
- `message`
- `trace_id`

Common optional fields include `error_type`, `order_number`, `sku`, `cron_name`, `connector_name`, `retry_count`, `http_status`, `source_system`, `target_system`, `diagnostic_ref`, and `diagnostic_size_bytes`.

Missing required fields are routed to `logs-invalid-*` and archived in `invalid-logs-local`. Severity is normalized to `debug`, `info`, `warn`, `error`, or `fatal`.

Full field guidance: [docs/04-logging-contract-and-fields.md](docs/04-logging-contract-and-fields.md).

## Dashboards and Reports

Open Dashboards at `http://localhost:5601` and use `Logging Observability Overview`.

`./scripts/apply-dashboards.sh` creates:

- Data views for `logs-local-*` and `logs-invalid-*`
- Saved searches for errors, fatals, connectors, cron jobs, trace lookup, diagnostics, and invalid logs
- Dashboard `Logging Observability Overview`

To reapply after a reset or customization:

```bash
./scripts/apply-dashboards.sh
```

Customize durable reports in `scripts/apply-dashboards.sh`, not only through manual UI edits. The detailed guide explains how to add fields, create multiple reports, and use sample data for connector, cron, business, diagnostic, and tenant-level reporting:

[docs/05-dashboards-reporting-and-customization.md](docs/05-dashboards-reporting-and-customization.md)

## Retention and Local Stress Tuning

`./scripts/apply-retention.sh` applies OpenSearch ISM policies and index templates.

Defaults:

- OpenSearch heap: `-Xms1g -Xmx1g`
- OpenSearch memory limit: `2g`
- Kafka topic partitions: `6`
- Kafka topic retention: `604800000` ms
- Kafka segment size: `268435456` bytes
- OpenSearch index refresh interval: `5s`
- Valid-log retention: 14 days, configurable with `OPENSEARCH_LOGS_RETENTION_DAYS`
- Invalid-log retention: 7 days, configurable with `OPENSEARCH_INVALID_RETENTION_DAYS`

## Stress Testing

The stress generator is disabled by default.

```bash
./scripts/generate-load.sh --rate 100 --duration 30
./scripts/generate-load.sh --rate 1000 --duration 60 --services checkout,orders --modules api,worker
./scripts/generate-load.sh --rate 5000 --duration 60 --message-size 512 --diagnostics true
docker compose --profile stress run --rm -e STRESS_RATE=1000 -e STRESS_DURATION=60 log-stress-tool
```

More detail: [docs/08-stress-testing.md](docs/08-stress-testing.md).

## Diagnostics

Large diagnostics should be compressed and stored in object storage. OpenSearch should index only `diagnostic_ref` and `diagnostic_size_bytes`.

```bash
./scripts/generate-diagnostic.sh
```

Vector removes inline `diagnostic_payload` before indexing to avoid storing MB-level payloads in OpenSearch.

## Integration Intake Checklist

Use this before connecting a new source:

- Owner/team and escalation contact
- Source system and environment
- Source IP/CIDR or network path
- Chosen intake type: HTTP, TCP, syslog, file-tail, stdout pattern
- `service`, `module`, `component`, and `event_type` naming
- Expected records/sec, message size, severity mix
- Optional fields needed for reports, such as `connector_name`, `cron_name`, `order_number`, `sku`, or custom fields
- Diagnostic strategy and maximum diagnostic size
- Retention and dashboard/reporting requirements
- Auth token, TLS/API gateway, rate limit, and firewall requirements

## Security and Firewall

Local defaults are for development. Do not expose ingestion publicly without protection.

Production controls:

- HTTPS termination
- API key or token validation
- Source identity
- Payload limits
- Rate limits
- Firewall rules for trusted source ranges only
- Private OpenSearch, Dashboards, Kafka, and MinIO access
- Secret rotation and audit logging

Full guide: [docs/06-security-firewall-and-intake.md](docs/06-security-firewall-and-intake.md).

## OpenSearch Queries

Find a trace:

```bash
curl -s "http://localhost:9200/logs-local-*/_search" \
  -H 'Content-Type: application/json' \
  -d '{"query":{"term":{"trace_id":"trace-123"}}}'
```

Find errors by service:

```bash
curl -s "http://localhost:9200/logs-local-*/_search" \
  -H 'Content-Type: application/json' \
  -d '{"query":{"bool":{"filter":[{"term":{"severity":"error"}},{"term":{"service":"checkout"}}]}}}'
```

Find diagnostics:

```bash
curl -s "http://localhost:9200/logs-local-*/_search" \
  -H 'Content-Type: application/json' \
  -d '{"query":{"exists":{"field":"diagnostic_ref"}}}'
```

## Documentation

- [docs/01-architecture.md](docs/01-architecture.md)
- [docs/02-setup.md](docs/02-setup.md)
- [docs/03-ingestion-integrations.md](docs/03-ingestion-integrations.md)
- [docs/04-logging-contract-and-fields.md](docs/04-logging-contract-and-fields.md)
- [docs/05-dashboards-reporting-and-customization.md](docs/05-dashboards-reporting-and-customization.md)
- [docs/06-security-firewall-and-intake.md](docs/06-security-firewall-and-intake.md)
- [docs/07-retention-storage-and-diagnostics.md](docs/07-retention-storage-and-diagnostics.md)
- [docs/08-stress-testing.md](docs/08-stress-testing.md)
- [docs/09-production-notes.md](docs/09-production-notes.md)
- [docs/10-troubleshooting.md](docs/10-troubleshooting.md)
- [docs/11-decision-log.md](docs/11-decision-log.md)
