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

ARG1="${1:-up}"

if [ "$ARG1" = "-d" ]; then
  CMD="up"
  EXTRA="-d ${*:2}"
else
  CMD="$ARG1"
  EXTRA="${*:2}"
fi

echo -e "${BLUE}🐳 docker compose --env-file $ENV_FILE $CMD $EXTRA${NC}"
# shellcheck disable=SC2086
docker compose --env-file "$ENV_FILE" "$CMD" $EXTRA

if [ "$CMD" = "up" ]; then
  echo -e "${GREEN}✅ Backend running at http://localhost:20080${NC}"
fi
