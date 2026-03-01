#!/bin/bash
# Remembite — Backend Runner
# Passes .env.api to docker compose for both variable substitution and container injection.
#
# Usage:
#   ./run-api.sh              # start (foreground)
#   ./run-api.sh -d           # start (detached)
#   ./run-api.sh down         # stop and remove containers

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

ENV_FILE=".env.api"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ $ENV_FILE not found. Copy from .env.api.example and fill in values."
  exit 1
fi

CMD="${1:-up}"

echo -e "${BLUE}🐳 docker compose --env-file $ENV_FILE $*${NC}"
docker compose --env-file "$ENV_FILE" "$@"

if [ "$CMD" = "up" ] || [ "$CMD" = "-d" ]; then
  echo -e "${GREEN}✅ Backend running at http://localhost:8080${NC}"
fi
