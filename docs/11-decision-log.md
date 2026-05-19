# Decision Log

## Vector for Ingestion and Processing

Vector is used because it provides lightweight, high-throughput ingestion, source support for HTTP, TCP, syslog, and files, built-in buffering, and VRL-based validation/enrichment.

## Kafka for Buffering

Kafka decouples external ingestion from downstream indexing and archiving. It provides buffering, replay, and operational isolation. For very low volume, Kafka may be simplified away later, but it is valuable for this central ingestion design.

## MinIO for Local Object Storage

MinIO is used locally because it provides S3-compatible object storage without requiring cloud credentials. It lets the platform exercise archive and diagnostic object flows during local development.

## Replacing MinIO with GCP Cloud Storage

Production can replace MinIO by changing Vector archive sinks to GCP Cloud Storage sinks, creating equivalent GCS buckets, and supplying secure credentials through workload identity or service account configuration. OpenSearch documents should keep the same `diagnostic_ref` concept.

## Separate Large Diagnostics

Large diagnostics are stored separately because indexing MB-level payloads in OpenSearch is expensive, slows search, increases heap pressure, and makes retention harder. OpenSearch indexes only `diagnostic_ref` and metadata needed to find the object.

## Optional Stress Generator

The stress generator is optional and behind a Compose profile because it is a test utility, not a primary log source. The platform must be useful for external systems without bundled sample applications.

## Real Dashboards Saved Objects

OpenSearch Dashboards saved objects are created through `scripts/apply-dashboards.sh` instead of remaining documentation-only placeholders. The local overview dashboard uses saved-search panels because they are portable across OpenSearch Dashboards versions and directly expose indexed records needed for triage. The default deployment also creates a pivot-style reporting dashboard for grouped operational summaries.

## Dashboard and Report Customization

Durable dashboard customization belongs in `scripts/apply-dashboards.sh`. Manual UI edits are acceptable for exploration, but scripted saved objects survive reset, migration, and future Codex sessions.

## Pivot-Style Reporting

Pivot-like reporting is part of the default Dockerized deployment through `Logging Pivot Reports`. It uses native OpenSearch Dashboards metric, pie, area, heatmap, Data Table, Controls, and saved-search panels because they can be applied automatically with `scripts/apply-dashboards.sh` and remain easier to maintain than custom Vega for common reporting. A full Excel-style pivot table remains outside the default scope, but grouped, filterable operational summaries are created by default. Vega should be reserved for visuals that native panels cannot express clearly, such as future Sankey-style flow or matrix reports.

## Local Retention and Stress Tuning

Local retention is enforced with OpenSearch ISM policies and Kafka topic retention so long-running stress tests do not grow unbounded. OpenSearch uses a larger local heap and a slower refresh interval to reduce indexing pressure, while Kafka uses six partitions to improve processor parallelism headroom.

## File-Tail Fingerprinting

Vector file-tail ingestion uses `device_and_inode` fingerprinting instead of checksum fingerprinting. Same-shaped generated JSONL test files can share the same leading content pattern, causing checksum-based checkpoints to skip a new test file. Device/inode fingerprinting avoids that local test failure mode.
