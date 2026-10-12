#!/usr/bin/env sh
set -eu
set +x

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
WORKSPACE_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd)
DEPLOY_ENV=${DIMAX_INFRA_ENV_FILE:-"${SCRIPT_DIR}/.env.local"}
BACKEND_COMPOSE="${WORKSPACE_ROOT}/backend/docker-compose.production.yml"
EDGE_COMPOSE="${SCRIPT_DIR}/docker-compose.edge.yml"

if [ ! -f "${DEPLOY_ENV}" ]; then
  echo "Missing deployment env: ${DEPLOY_ENV}" >&2
  exit 2
fi

case "${1:-}" in
  ''|--check) ;;
  *) echo 'Usage: deploy.sh [--check]' >&2; exit 2 ;;
esac
if [ "$#" -gt 1 ]; then
  echo 'Usage: deploy.sh [--check]' >&2
  exit 2
fi

compose() {
  docker compose \
    --env-file "${DEPLOY_ENV}" \
    -f "${BACKEND_COMPOSE}" \
    -f "${EDGE_COMPOSE}" \
    "$@"
}

command -v python3 >/dev/null 2>&1 || { echo 'Python 3 is required for preflight.' >&2; exit 2; }
# Compose parses env as data; never source it or print the rendered secrets.
if ! rendered=$(compose --profile tools config --format json 2>/dev/null); then
  echo 'Cannot render Compose configuration; check the deployment/backend env files.' >&2
  exit 2
fi
preflight() {
  if [ "${DIMAX_RUN_BOOTSTRAP:-false}" = "true" ]; then
    printf '%s\n' "$rendered" | python3 "${SCRIPT_DIR}/preflight.py" --bootstrap "$@"
  else
    printf '%s\n' "$rendered" | python3 "${SCRIPT_DIR}/preflight.py" "$@"
  fi
}
preflight

if [ "${1:-}" = "--check" ]; then
  echo "DIMAX production preflight passed. No services were changed; DNS/TLS/SMTP delivery remain unverified."
  exit 0
fi

compose pull
preflight --inspect-admin-image
compose --profile tools run --rm migrate

if [ "${DIMAX_RUN_BOOTSTRAP:-false}" = "true" ]; then
  compose --profile tools run --rm bootstrap
fi

compose up -d --wait --wait-timeout 180
compose ps

echo "Deployment is healthy. Verify the configured public API /ready and business smoke before GO."

