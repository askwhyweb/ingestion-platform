# Retention, Storage, and Diagnostics

## OpenSearch Retention

`scripts/apply-retention.sh` applies Index State Management policies and index templates.

Configured local defaults:

- `logs-local-*`: 14 days through `logs-local-retention-policy`.
- `logs-invalid-*`: 7 days through `logs-invalid-retention-policy`.
- Refresh interval: `5s`.
- Total field limit: `2000`.

Environment variables:

- `OPENSEARCH_LOGS_RETENTION_DAYS`
- `OPENSEARCH_INVALID_RETENTION_DAYS`

Reapply:

```bash
./scripts/apply-retention.sh
```

## Kafka Retention

`logs.raw` defaults:

- Partitions: `6`
- Retention: `604800000` ms
- Segment size: `268435456` bytes
- Cleanup policy: `delete`

`kafka/init-topics.sh` creates the topic and idempotently increases partitions when the configured partition count is higher.

## MinIO Buckets

- `logs-archive-local`: compressed valid logs.
- `invalid-logs-local`: compressed invalid logs.
- `diagnostics-local`: large diagnostic objects.

MinIO local lifecycle cleanup is not enabled by default. Use bucket lifecycle rules in production object storage.

## Diagnostics Lifecycle

Large diagnostics should not be indexed. Store the object in MinIO or cloud storage, then log:

- `diagnostic_ref`
- `diagnostic_size_bytes`

Helper:

```bash
./scripts/generate-diagnostic.sh
```

## Replacing MinIO with GCP Cloud Storage

1. Create GCS buckets equivalent to local buckets.
2. Replace Vector `aws_s3` archive sinks with `gcp_cloud_storage` sinks.
3. Provide credentials with workload identity or a securely mounted service account.
4. Preserve `diagnostic_ref` semantics so OpenSearch dashboards continue to work.

