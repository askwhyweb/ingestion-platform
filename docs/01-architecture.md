# Architecture

This platform is a local centralized logging pipeline. It is built with Docker Compose and is designed to receive logs from external systems, not from bundled demo applications.

## Data Flow

```text
external systems
  -> vector-ingest
  -> Kafka topic logs.raw
  -> vector-processor
  -> OpenSearch logs-local-* and logs-invalid-*
  -> MinIO compressed archives and diagnostics
  -> OpenSearch Dashboards saved searches and dashboard
```

## Service Responsibilities

| Service | Responsibility |
| --- | --- |
| `vector-ingest` | Accept HTTP JSON, TCP JSON lines, syslog TCP/UDP, and mounted file-tail input. Add source metadata and forward events to Kafka. |
| `kafka` | Buffer raw events in `logs.raw`, provide replay headroom, and decouple intake from indexing/archive availability. |
| `kafka-init` | Create or update `logs.raw` topic settings. |
| `vector-processor` | Consume from Kafka, validate required fields, normalize severity, remove inline diagnostic payloads, enrich events, and route valid/invalid logs. |
| `opensearch` | Store searchable valid logs in `logs-local-*` and invalid logs in `logs-invalid-*`. |
| `opensearch-dashboards` | Provide data views, saved searches, and `Logging Observability Overview`. |
| `minio` | Store compressed valid archives, invalid archives, and diagnostic objects locally. |
| `minio-init` | Create required MinIO buckets. |
| `log-stress-tool` | Optional test utility behind the `stress` Compose profile. |

## Ports

| Port | Service | Purpose |
| --- | --- | --- |
| `8080` | Vector ingest | HTTP JSON intake |
| `9002` | Vector ingest | TCP JSON lines intake |
| `5514/tcp` and `5514/udp` | Vector ingest | Syslog intake |
| `9200` | OpenSearch | Local API |
| `5601` | OpenSearch Dashboards | Local UI/API |
| `9000` | MinIO | S3-compatible API |
| `9001` | MinIO | Console |
| `19092` | Kafka | Host debug access |

## Failure Boundaries

Kafka protects the central intake path from short downstream failures. If OpenSearch or MinIO pauses, Kafka can retain events while Vector processor recovers. Vector sinks use disk buffers where practical. MinIO is a local stand-in for object storage; production should use durable cloud object storage.

## Storage Destinations

- Valid searchable logs: `logs-local-YYYY.MM.DD`
- Invalid searchable logs: `logs-invalid-YYYY.MM.DD`
- Valid archives: MinIO bucket `logs-archive-local`
- Invalid archives: MinIO bucket `invalid-logs-local`
- Large diagnostics: MinIO bucket `diagnostics-local`

