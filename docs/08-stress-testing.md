# Stress Testing

Stress generation is a test utility only. It is disabled by default.

## Script Examples

```bash
./scripts/generate-load.sh --rate 100 --duration 30
./scripts/generate-load.sh --rate 1000 --duration 60 --severity-mix debug:5,info:70,warn:15,error:8,fatal:2
./scripts/generate-load.sh --rate 5000 --duration 60 --services checkout,orders,inventory --modules api,worker,connector,cron --message-size 512 --diagnostics true
```

## Compose Profile

```bash
docker compose --profile stress run --rm -e STRESS_RATE=1000 -e STRESS_DURATION=60 log-stress-tool
```

Options:

- `--rate`
- `--duration`
- `--services`
- `--modules`
- `--severity-mix`
- `--message-size`
- `--diagnostics`

## Local Tuning Defaults

- OpenSearch heap: `-Xms1g -Xmx1g`
- OpenSearch container memory: `2g`
- Kafka topic partitions: `6`
- Kafka retention: 7 days
- Kafka segment size: 256 MB
- OpenSearch refresh interval: `5s`

## Interpreting Results

Watch:

- OpenSearch indexing errors.
- Kafka lag.
- Vector processor errors.
- MinIO write errors.
- Host CPU, memory, and disk I/O.

High local rates depend on host CPU, Docker networking, OpenSearch heap, disk speed, and payload size.

