# Current Status

## Current Phase

Complete. Platform is built, running, tuned, documented with human-friendly numbered guides, and validated locally.

## Completed Work

- Confirmed the workspace started empty.
- Confirmed Docker is available and the user reported local Docker setup is now functional.
- Created required project directories.
- Created this continuity status file.
- Created the initial platform file set.
- Validated shell script syntax and Docker Compose syntax.
- Confirmed Linux `docker` client cannot reach `/var/run/docker.sock`, but `docker.exe` can reach Docker Desktop.
- Validated Vector ingest and processor configs through `docker.exe run` with healthchecks skipped.
- Started the Docker Compose stack and applied the OpenSearch index template.
- Confirmed HTTP, TCP, syslog, file-tail, and invalid-log routing in the second pipeline test.
- Completed full pipeline validation including MinIO valid archive, MinIO invalid archive, diagnostic object storage, and `diagnostic_ref` search.
- Verified stress generation through the optional Compose `stress` profile and through the direct script.
- Verified fresh HTTP events no longer index or archive the bearer token.
- Added `.gitignore` for `.tmp/` diagnostic staging files.
- Created real OpenSearch Dashboards saved objects through `scripts/apply-dashboards.sh`.
- Added OpenSearch ISM retention policies and split valid/invalid index templates through `scripts/apply-retention.sh`.
- Tuned local sustained-stress defaults: OpenSearch 1 GB heap, 2 GB container memory, Kafka 6 partitions, 7-day Kafka retention, 256 MB Kafka segments, and 5-second OpenSearch refresh intervals.
- Fixed file-tail fingerprinting by switching Vector file input to `device_and_inode`; full pipeline validation now passes after the fix.
- Fixed and revalidated the WSL/Docker Desktop diagnostic copy path in `scripts/generate-diagnostic.sh`.
- Rewrote `README.md` as the first-stop human guide for overview, quick start, integrations, dashboards, security, retention, stress testing, diagnostics, intake, and operations.
- Reorganized `/docs` into numbered guides from `docs/01-architecture.md` through `docs/11-decision-log.md`.
- Added detailed integration guidance for HTTP JSON, TCP JSON lines, syslog, file-tail, stdout patterns, cron/connector sources, Docker logs, and diagnostics.
- Added detailed OpenSearch Dashboards customization guidance for supported fields, adding mapped fields, creating multiple reports, customizing reports by ingestion data, and using concrete sample payloads.
- Added security, firewall, intake, retention, storage, stress testing, production, troubleshooting, and decision-log documentation aligned with the README.
- Updated `AI-Instructions.md` so the numbered docs structure and dashboard/report customization rules are part of the project continuity standard.
- Added AGPLv3 license-aware project summary to the top of `README.md` for public repository presentation.
- Documented how the HTTP bearer token is configured through `VECTOR_HTTP_TOKEN` in `.env`, including local default use, token replacement, restart requirement, and production handling.

## Pending Work

- None required for the requested local platform.

## Known Issues

- Linux `docker` client socket issue remains in this shell, but all working scripts fall back to `docker.exe compose`.
- OpenSearch Dashboards saved objects are now real imported objects. They are intentionally simple saved-search panels, with documentation explaining how to add richer searches/reports and durable script-backed customizations.

## Last Successful Command

`docker compose config >/tmp/token-doc-compose-config.out && bash -n scripts/*.sh kafka/init-topics.sh && sh -n minio/init-buckets.sh`

## Last Failed Command

None active after latest validation. Historical failures fixed or rechecked:
- `./scripts/test-pipeline.sh` failed inside `scripts/generate-diagnostic.sh` with `GetFileAttributesEx D:\mnt...`; fixed by converting WSL paths for `docker.exe compose cp`.
- Post-tuning file-tail timeout was fixed by changing Vector file fingerprinting to `device_and_inode`.
- During documentation validation, one `./scripts/test-pipeline.sh` run timed out waiting for `trace-diagnostic-test-1779007018`; a direct diagnostic send and a full rerun both passed, so this is recorded as a transient miss with no active blocker.

## Next Recommended Action

No required next action. Use `./scripts/down.sh` when finished with the running local stack.

## Acceptance Criteria Status

- Platform files created: complete
- Compose validation: complete
- Vector validation: complete
- Platform startup: complete
- HTTP ingestion: complete
- TCP ingestion: complete
- Syslog ingestion: complete
- File-tail ingestion: complete
- OpenSearch search: complete
- MinIO archive: complete
- Invalid log routing: complete
- Stress generator: complete
- Diagnostic archive and `diagnostic_ref` search: complete
- Real Dashboards saved objects: complete
- Local heap/retention tuning: complete
- Human-friendly README and numbered docs: complete
- Dashboard/report customization documentation with sample data: complete
- Continuity files updated: complete
