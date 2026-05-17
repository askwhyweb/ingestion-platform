#!/usr/bin/env bash
set -euo pipefail

repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

compose_cmd() {
  if docker info >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    echo "docker compose"
  elif command -v docker.exe >/dev/null 2>&1 && docker.exe info >/dev/null 2>&1 && docker.exe compose version >/dev/null 2>&1; then
    echo "docker.exe compose"
  elif command -v docker-compose >/dev/null 2>&1; then
    echo "docker-compose"
  else
    echo "No Docker Compose command found" >&2
    return 1
  fi
}

load_env() {
  local root
  root="$(repo_root)"
  if [ -f "${root}/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    . "${root}/.env"
    set +a
  fi
}

wait_for_http() {
  local url="$1"
  local name="$2"
  local timeout="${3:-120}"
  local start
  start="$(date +%s)"
  while true; do
    if curl -fsS "${url}" >/dev/null 2>&1; then
      echo "${name} is ready"
      return 0
    fi
    if [ $(( "$(date +%s)" - start )) -ge "${timeout}" ]; then
      echo "Timed out waiting for ${name} at ${url}" >&2
      return 1
    fi
    sleep 2
  done
}
