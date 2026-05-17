# Security, Firewall, and Intake

Local defaults are for development. Do not expose the platform publicly without a protective layer.

## Port Matrix

| Port | Protocol | Service | Exposure guidance |
| --- | --- | --- | --- |
| `8080` | HTTP | Vector ingest | Expose only through HTTPS/API gateway or trusted private network |
| `9002` | TCP | Vector ingest | Expose only to trusted stream senders |
| `5514` | TCP/UDP | Vector ingest syslog | Expose only to trusted syslog sources |
| `9200` | HTTP | OpenSearch | Keep private |
| `5601` | HTTP | Dashboards | Keep private or protect with SSO/VPN |
| `9000` | HTTP/S3 | MinIO API | Keep private |
| `9001` | HTTP | MinIO Console | Keep private |
| `19092` | TCP | Kafka host debug | Keep private; disable host exposure in production if not needed |

## Firewall Guidance

- Allow ingestion ports only from known source CIDRs.
- Keep OpenSearch, Dashboards, Kafka, and MinIO on private networks.
- Prefer VPN, private link, or internal load balancers for operational access.
- Put HTTPS termination and API key validation in front of HTTP ingestion.
- Rate limit by source identity and expected volume.

## Production Controls

- HTTPS termination.
- API key or token validation.
- Per-source identity.
- Payload size limits.
- Rate limits and quotas.
- Audit logging for ingestion and administration.
- Secret rotation.
- Monitoring for Kafka lag, Vector errors, OpenSearch indexing failures, and object storage write failures.

## HTTP Bearer Token Handling

Local HTTP ingestion uses `VECTOR_HTTP_TOKEN` from `.env`. The default value from `.env.example` is `change-me-local-token`, which is only a development placeholder.

For local testing:

```text
Authorization: Bearer change-me-local-token
```

For a shared environment:

- Generate a long random token, for example with `openssl rand -hex 32`.
- Store it in `.env` as `VECTOR_HTTP_TOKEN`.
- Restart `vector-ingest` after changing it.
- Give the token only to approved source-system owners.
- Rotate it through the integration intake process.
- Prefer a reverse proxy or API gateway for per-source tokens, rate limits, TLS, request size limits, and audit logs.

The built-in Vector check is intentionally simple and accepts one configured token. Production deployments should normally move token issuance, per-source identity, and rotation to an API gateway or ingress layer.

## Intake Checklist

Use this for every new integration:

- Source owner/team and escalation contact.
- Source system and environment.
- Source IP/CIDR or network path.
- Chosen intake type: HTTP, TCP, syslog, file-tail, stdout pattern.
- Auth token/API key and rotation owner.
- Expected records/sec, burst size, message size, and severity mix.
- Required field values: `service`, `module`, `component`, `event_type`.
- Optional reporting fields: `connector_name`, `cron_name`, `order_number`, `sku`, `tenant_id`, or similar.
- Diagnostic behavior and maximum diagnostic size.
- Retention requirements.
- Dashboard/reporting requirements.
