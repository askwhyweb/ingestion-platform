#!/usr/bin/env sh
set -eu

mc alias set local http://minio:9000 "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}"
mc mb --ignore-existing "local/${LOGS_ARCHIVE_BUCKET}"
mc mb --ignore-existing "local/${DIAGNOSTICS_BUCKET}"
mc mb --ignore-existing "local/${INVALID_LOGS_BUCKET}"
mc ls local

