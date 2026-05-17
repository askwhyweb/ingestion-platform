#!/usr/bin/env bash
set -euo pipefail

topic="${KAFKA_TOPIC_RAW:-logs.raw}"
partitions="${KAFKA_TOPIC_PARTITIONS:-6}"
retention_ms="${KAFKA_TOPIC_RETENTION_MS:-604800000}"
segment_bytes="${KAFKA_TOPIC_SEGMENT_BYTES:-268435456}"

echo "Creating Kafka topic ${topic} with ${partitions} partitions if needed"
/opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka:9092 \
  --create \
  --if-not-exists \
  --topic "${topic}" \
  --partitions "${partitions}" \
  --replication-factor 1 \
  --config "retention.ms=${retention_ms}" \
  --config "segment.bytes=${segment_bytes}" \
  --config "cleanup.policy=delete"

current_partitions="$(
  /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:9092 --describe --topic "${topic}" |
    sed -n 's/.*PartitionCount: \([0-9][0-9]*\).*/\1/p' |
    head -1
)"

if [ -n "${current_partitions}" ] && [ "${current_partitions}" -lt "${partitions}" ]; then
  echo "Increasing Kafka topic ${topic} partitions from ${current_partitions} to ${partitions}"
  /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server kafka:9092 \
    --alter \
    --topic "${topic}" \
    --partitions "${partitions}"
fi

/opt/kafka/bin/kafka-configs.sh \
  --bootstrap-server kafka:9092 \
  --entity-type topics \
  --entity-name "${topic}" \
  --alter \
  --add-config "retention.ms=${retention_ms},segment.bytes=${segment_bytes},cleanup.policy=delete"

/opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:9092 --describe --topic "${topic}"
