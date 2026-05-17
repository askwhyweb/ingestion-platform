# Production Notes

This Compose stack is local-first. Production should separate infrastructure and harden network/security boundaries.

## Recommended Topology

- Application servers run local Vector agents or structured logging libraries.
- A protected ingestion gateway accepts logs over HTTPS, TCP, syslog, or agent forwarding.
- Kafka runs as managed or dedicated infrastructure.
- Vector processors run separately from application nodes.
- OpenSearch runs as managed or dedicated infrastructure.
- Object storage should be cloud storage such as GCP Cloud Storage.

## Security

- Never expose unauthenticated ingestion publicly.
- Keep OpenSearch, Dashboards, Kafka, and object storage private.
- Use HTTPS, API keys, source identity, rate limits, payload limits, and audit logging.
- Rotate secrets and treat diagnostic objects as potentially sensitive.

## Kafka Optionality

Kafka may be removed for very low volume if direct Vector-to-OpenSearch/Object-Storage delivery is acceptable. Keep Kafka when buffering, replay, and operational isolation matter.

## Vector Agents

Run lightweight Vector agents on application servers when sources emit stdout, local files, or application logs that should not directly call the central gateway.

