#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=scripts/common.sh
. scripts/common.sh
load_env

compose="$(compose_cmd)"
if [ "${1:-}" = "--volumes" ]; then
  ${compose} down -v
else
  ${compose} down
fi

