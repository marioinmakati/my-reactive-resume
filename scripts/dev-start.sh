#!/usr/bin/env bash
# Start shared infra services, then launch the dev server.
set -e

INFRA_SCRIPT="/root/workspace/env/my-docker-config/infra/scripts/infra.sh"

if [[ ! -f "$INFRA_SCRIPT" ]]; then
  echo "infra.sh not found at $INFRA_SCRIPT"
  exit 1
fi

# Load infra helpers (defines infra-up, etc.)
# shellcheck source=/dev/null
source "$INFRA_SCRIPT"

# Start shared PostgreSQL (Browserless runs as reactive-browserless standalone container)
infra-up postgres
sudo docker start reactive-browserless 2>/dev/null || true

echo "Infrastructure ready. Starting dev server..."
pnpm exec vp dev
