# AI Instructions

This file is the single source of truth for the logging and observability ingestion platform. At the start of every Codex session, read this file, `current-status.md`, and `output.txt` before changing anything.

## Goal

Build a Dockerized centralized logging and observability ingestion platform that accepts logs from external systems through HTTP JSON, TCP JSON lines, syslog, and mounted file ingestion. The platform must not rely on fixed bundled sample applications as the primary log source. Stress generation is allowed only as an optional test utility.

## Architecture

External systems send logs to `vector-ingest`. `vector-ingest` accepts HTTP, TCP, syslog, and file-tail input, then forwards normalized raw events to Kafka in buffered mode. `vector-processor` consumes from Kafka, validates and enriches logs, indexes searchable records into OpenSearch, and archives compressed records to MinIO. OpenSearch Dashboards provides human search/reporting through real saved objects applied by `scripts/apply-dashboards.sh`. MinIO is the local object storage replacement for GCP Cloud Storage.

Required services:

- `vector-ingest`
- `kafka`
- `kafka-init`
- `vector-processor`
- `opensearch`
- `opensearch-dashboards`
- `minio`
- `minio-init`
- optional `log-stress-tool` using the `stress` Docker Compose profile only

## Required Repository Structure

- `docker-compose.yml`
- `.env.example`
- `README.md`
- `AI-Instructions.md`
- `current-status.md`
- `output.txt`
- `vector/ingest/vector.yaml`
- `vector/processor/vector.yaml`
- `kafka/init-topics.sh`
- `minio/init-buckets.sh`
- `opensearch/index-template.json`
- `scripts/up.sh`
- `scripts/down.sh`
- `scripts/send-log-http.sh`
- `scripts/send-log-tcp.sh`
- `scripts/send-log-syslog.sh`
- `scripts/generate-load.sh`
- `scripts/generate-diagnostic.sh`
- `scripts/test-pipeline.sh`
- `logs/incoming/.gitkeep`
- `docs/01-architecture.md`
- `docs/02-setup.md`
- `docs/03-ingestion-integrations.md`
- `docs/04-logging-contract-and-fields.md`
- `docs/05-dashboards-reporting-and-customization.md`
- `docs/06-security-firewall-and-intake.md`
- `docs/07-retention-storage-and-diagnostics.md`
- `docs/08-stress-testing.md`
- `docs/09-production-notes.md`
- `docs/10-troubleshooting.md`
- `docs/11-decision-log.md`

## Ingestion Contract

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

Optional fields:

- `error_type`
- `order_number`
- `sku`
- `cron_name`
- `connector_name`
- `retry_count`
- `http_status`
- `source_system`
- `target_system`
- `diagnostic_ref`
- `diagnostic_size_bytes`

Validation and normalization rules:

- Missing required fields must be tagged with `invalid_log: true`.
- Invalid logs must be routed to a separate OpenSearch index and invalid archive path.
- Severity must be normalized to `debug`, `info`, `warn`, `error`, or `fatal`.
- Host/source metadata must be added.
- Preserve the original event in `raw_event` where practical.
- MB-level diagnostic payloads must not be indexed into OpenSearch. Store diagnostics in object storage and index only `diagnostic_ref` and `diagnostic_size_bytes`.

## Storage

- Valid OpenSearch indices use daily names like `logs-local-YYYY.MM.DD`.
- Invalid OpenSearch indices use daily names like `logs-invalid-YYYY.MM.DD`.
- Local OpenSearch templates attach ISM retention policies: 14 days for valid logs and 7 days for invalid logs.
- Local sustained-stress defaults use 1 GB OpenSearch heap, 2 GB OpenSearch container memory, 6 Kafka partitions, 7-day Kafka topic retention, 256 MB Kafka segments, and 5-second OpenSearch refresh intervals.
- MinIO buckets:
  - `logs-archive-local`
  - `diagnostics-local`
  - `invalid-logs-local`
- Archive logs should be gzip-compressed where practical.
- Large diagnostics are stored separately and referenced with `diagnostic_ref`.

## Security and Production Rules

- Do not assume public unauthenticated ingestion is safe.
- HTTP ingestion must support token-based protection.
- Production exposure must use HTTPS, API keys, payload limits, source identity, and rate limits.
- Kafka is optional for very low volume but useful for buffering and replay at higher volume.
- Production Kafka, OpenSearch, and Vector processor should run on dedicated infrastructure.
- Vector agents can run on application servers as lightweight services.
- MinIO is local object storage only; production can replace it with GCP Cloud Storage by switching the archive sink and credentials.

## Continuity Rules

- Keep `AI-Instructions.md`, `current-status.md`, and `output.txt` updated throughout the build.
- `current-status.md` must show current phase, completed work, pending work, known issues, last successful command, last failed command, next recommended action, and acceptance criteria status.
- `output.txt` is append-only where practical and logs commands, important outputs, errors, fixes, validation results, and final status.
- `docs/11-decision-log.md` must record key decisions and reasons.
- If implementation deviates from this file, update this file first or record the deviation in `current-status.md` with a reason.
- Do not mark complete only because files exist. Completion requires validation commands where possible.
- If blocked, record the exact error, suspected cause, and next action in `current-status.md` and `output.txt`.
- Every major change must keep `README.md` and docs aligned.
- `README.md` is the human-friendly entrypoint for the application. The `/docs` folder must stay numbered and sorted by setup flow, integration flow, dashboard/reporting customization, security, operations, and decisions.
- OpenSearch Dashboards reporting customization must document supported fields, adding mapped fields, creating multiple reports, script-based saved object customization, and realistic payload examples.

## Acceptance Criteria

- `docker compose up` or fallback `docker-compose up` starts the platform.
- External curl request sends a log successfully.
- TCP JSON log can be sent successfully.
- Syslog test can be sent successfully where practical.
- File placed in `./logs/incoming` is ingested.
- Logs are searchable in OpenSearch.
- Archive copy appears in MinIO.
- Invalid logs are tagged or routed separately.
- Stress generator can generate configurable load and is disabled by default.
- `diagnostic_ref` can be searched in OpenSearch.
- Large diagnostic sample is stored in MinIO as a compressed file.
- README explains MinIO to GCP Cloud Storage migration.
- README explains moving from local Docker to production servers.
- `current-status.md` accurately reflects completed and pending work.
- `output.txt` contains command and test history.
- `docs/11-decision-log.md` records key decisions.
