#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
WORKSPACE_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd)
DEPLOY_ENV=${DIMAX_INFRA_ENV_FILE:-"${SCRIPT_DIR}/.env.local"}
BACKEND_COMPOSE="${WORKSPACE_ROOT}/backend/docker-compose.production.yml"
EDGE_COMPOSE="${SCRIPT_DIR}/docker-compose.edge.yml"

if [ ! -f "${DEPLOY_ENV}" ]; then
  echo "Missing deployment env: ${DEPLOY_ENV}" >&2
  exit 2
fi

set -a
# shellcheck disable=SC1090
. "${DEPLOY_ENV}"
set +a

if [ ! -f "${DIMAX_BACKEND_ENV_FILE:-}" ]; then
  echo "Missing backend production env: ${DIMAX_BACKEND_ENV_FILE:-unset}" >&2
  exit 2
fi

compose() {
  docker compose \
    --env-file "${DEPLOY_ENV}" \
    -f "${BACKEND_COMPOSE}" \
    -f "${EDGE_COMPOSE}" \
    "$@"
}

compose config --quiet

if [ "${1:-}" = "--check" ]; then
  echo "DIMAX production Compose contract is valid."
  exit 0
fi

compose pull
compose --profile tools run --rm migrate

if [ "${DIMAX_RUN_BOOTSTRAP:-false}" = "true" ]; then
  compose --profile tools run --rm bootstrap
fi

compose up -d --remove-orphans
compose ps

echo "Deployment started. Verify https://${DIMAX_API_HOST}/ready and the business smoke before GO."

