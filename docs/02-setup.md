# Setup

## Requirements

- Docker with Compose support
- `bash`, `curl`, and `nc`
- Enough Docker memory for OpenSearch; local defaults use a 2 GB OpenSearch container limit

On this workspace, scripts can fall back to `docker.exe compose` when the Linux Docker socket is unavailable.

## Start

```bash
cp .env.example .env
./scripts/up.sh
```

`./scripts/up.sh` starts the stack, waits for OpenSearch, applies retention/index templates, and applies OpenSearch Dashboards saved objects.

## Validate

```bash
docker compose config
bash -n scripts/*.sh kafka/init-topics.sh
sh -n minio/init-buckets.sh
./scripts/test-pipeline.sh
```

## Stop

```bash
./scripts/down.sh
```

Remove volumes only when local data can be discarded:

```bash
./scripts/down.sh --volumes
```

## Reapply Bootstrap Objects

```bash
./scripts/apply-retention.sh
./scripts/apply-dashboards.sh
```

Run these after deleting OpenSearch/Dashboards data or after changing templates, policies, saved searches, or dashboard definitions.

## Useful URLs

- OpenSearch: `http://localhost:9200`
- Dashboards: `http://localhost:5601`
- MinIO API: `http://localhost:9000`
- MinIO Console: `http://localhost:9001`

Default local credentials and tokens are in `.env.example`.

## HTTP Ingestion Token

The HTTP bearer token is the value of `VECTOR_HTTP_TOKEN` in `.env`.

After copying `.env.example`:

```bash
cp .env.example .env
rg VECTOR_HTTP_TOKEN .env
```

The default local value is `change-me-local-token`. Use it as:

```text
Authorization: Bearer change-me-local-token
```

For anything beyond local testing, generate a replacement token and update `.env`:

```bash
openssl rand -hex 32
```

Then restart the ingest service:

```bash
docker compose up -d --force-recreate vector-ingest
```

The scripts read `.env`, so `scripts/send-log-http.sh`, `scripts/generate-load.sh`, `scripts/generate-diagnostic.sh`, and `scripts/test-pipeline.sh` automatically use the configured token.

## WSL and Docker Desktop Note

If `docker` cannot reach `/var/run/docker.sock`, the project scripts try `docker.exe compose`. This is expected in some WSL/Docker Desktop setups.
