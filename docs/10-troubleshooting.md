# Troubleshooting

## Compose Command Fails

```bash
docker compose version
docker.exe compose version
docker-compose version
```

Scripts prefer `docker compose`, then `docker.exe compose`, then `docker-compose`.

## OpenSearch Does Not Start

```bash
docker logs ingestion-opensearch
```

Increase Docker memory if OpenSearch exits during bootstrap.

## Vector Config Fails

```bash
docker run --rm -v "$PWD/vector/ingest/vector.yaml:/etc/vector/vector.yaml:ro" timberio/vector:latest-debian validate /etc/vector/vector.yaml
docker run --rm -v "$PWD/vector/processor/vector.yaml:/etc/vector/vector.yaml:ro" timberio/vector:latest-debian validate /etc/vector/vector.yaml
```

## No Logs in OpenSearch

```bash
docker logs ingestion-vector-ingest
docker logs ingestion-vector-processor
docker logs ingestion-kafka
curl http://localhost:9200/_cat/indices?v
```

## File-Tail Logs Are Missed

The file source uses `device_and_inode` fingerprinting so same-shaped JSONL files are not skipped because their content prefix matches an older test file.

```bash
rm -f logs/incoming/test-*.jsonl
docker compose up -d --force-recreate vector-ingest
./scripts/test-pipeline.sh
```

## Dashboards Are Missing

```bash
./scripts/apply-dashboards.sh
curl 'http://localhost:5601/api/saved_objects/_find?type=dashboard&search=Logging%20Observability%20Overview&search_fields=title' -H 'osd-xsrf: true'
```

## No Archive Objects in MinIO

```bash
docker exec ingestion-minio mc alias set local http://localhost:9000 minioadmin minioadmin123
docker exec ingestion-minio mc ls local
docker exec ingestion-minio mc find local/logs-archive-local
```

## HTTP Ingestion Is Rejected

Confirm the bearer token matches `VECTOR_HTTP_TOKEN` in `.env`.

The local token is configured by you. It is not retrieved from Vector, OpenSearch, Kafka, or MinIO.

Check it with:

```bash
rg VECTOR_HTTP_TOKEN .env
```

Then send:

```text
Authorization: Bearer <that value>
```

If you changed `VECTOR_HTTP_TOKEN`, recreate the ingest container so Vector reloads the environment:

```bash
docker compose up -d --force-recreate vector-ingest
```

## Diagnostic Copy Fails on WSL

`scripts/generate-diagnostic.sh` converts WSL paths to Windows paths when using `docker.exe compose`. If copy errors return `GetFileAttributesEx`, confirm `wslpath` exists and run from the repository path under `/mnt/...`.
