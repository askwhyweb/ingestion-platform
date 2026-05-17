#!/usr/bin/env bash
set -euo pipefail

url="${VECTOR_HTTP_URL:-http://localhost:${VECTOR_HTTP_PORT:-8080}/logs}"
token="${VECTOR_HTTP_TOKEN:-change-me-local-token}"
rate="${STRESS_RATE:-100}"
duration="${STRESS_DURATION:-30}"
services="${STRESS_SERVICES:-checkout,orders,inventory}"
modules="${STRESS_MODULES:-api,worker,connector,cron}"
severity_mix="${STRESS_SEVERITY_MIX:-debug:5,info:70,warn:15,error:8,fatal:2}"
message_size="${STRESS_MESSAGE_SIZE:-256}"
diagnostics="${STRESS_DIAGNOSTICS:-false}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --url) url="$2"; shift 2 ;;
    --token) token="$2"; shift 2 ;;
    --rate) rate="$2"; shift 2 ;;
    --duration) duration="$2"; shift 2 ;;
    --services) services="$2"; shift 2 ;;
    --modules) modules="$2"; shift 2 ;;
    --severity-mix) severity_mix="$2"; shift 2 ;;
    --message-size) message_size="$2"; shift 2 ;;
    --diagnostics) diagnostics="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

IFS=',' read -r -a service_arr <<< "${services}"
IFS=',' read -r -a module_arr <<< "${modules}"

choose_severity() {
  local roll cumulative item sev weight
  roll=$((RANDOM % 100 + 1))
  cumulative=0
  IFS=',' read -r -a mix_arr <<< "${severity_mix}"
  for item in "${mix_arr[@]}"; do
    sev="${item%%:*}"
    weight="${item##*:}"
    cumulative=$((cumulative + weight))
    if [ "${roll}" -le "${cumulative}" ]; then
      echo "${sev}"
      return 0
    fi
  done
  echo "info"
}

make_message() {
  local base pad_len
  base="$1"
  if [ "${#base}" -ge "${message_size}" ]; then
    printf '%s' "${base:0:${message_size}}"
    return
  fi
  pad_len=$((message_size - ${#base}))
  printf '%s%*s' "${base}" "${pad_len}" "" | tr ' ' x
}

echo "Generating ${rate} records/sec for ${duration}s to ${url}"
end=$((SECONDS + duration))
sent=0

while [ "${SECONDS}" -lt "${end}" ]; do
  second_start="${SECONDS}"
  for ((i=0; i<rate; i++)); do
    service="${service_arr[$((RANDOM % ${#service_arr[@]}))]}"
    module="${module_arr[$((RANDOM % ${#module_arr[@]}))]}"
    severity="$(choose_severity)"
    trace_id="stress-$(date +%s)-${sent}"
    message="$(make_message "Stress log ${sent} for ${service}/${module}")"
    diag_fields=""
    if [ "${diagnostics}" = "true" ] && [ $((sent % 100)) -eq 0 ]; then
      diag_fields=',"diagnostic_ref":"s3://diagnostics-local/stress/sample-'${sent}'.json.gz","diagnostic_size_bytes":1048576'
    fi
    payload=$(printf '{"@timestamp":"%s","environment":"local","service":"%s","module":"%s","component":"stress-generator","severity":"%s","event_type":"stress_test","message":"%s","trace_id":"%s","source_system":"stress-tool"%s}' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${service}" "${module}" "${severity}" "${message}" "${trace_id}" "${diag_fields}")
    curl -fsS -X POST "${url}" -H "Authorization: Bearer ${token}" -H "Content-Type: application/json" -d "${payload}" >/dev/null &
    sent=$((sent + 1))
    if [ $((sent % 100)) -eq 0 ]; then
      wait
    fi
  done
  wait
  while [ "${SECONDS}" -eq "${second_start}" ]; do
    sleep 0.05
  done
done

echo "Generated ${sent} log records"

