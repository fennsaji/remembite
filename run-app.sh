#!/usr/bin/env bash
# Remembite — Mobile App Runner
# Loads env vars and runs Flutter on an emulator or connected device.
#
# Usage:
#   ./run-app.sh                             # default: .env.android, auto-pick device
#   ./run-app.sh .env.android                # Android emulator (10.0.2.2)
#   ./run-app.sh .env.ios                    # iOS simulator (localhost)
#   ./run-app.sh .env.android emulator-5554  # explicit device ID

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ENV_FILE="${1:-.env.android}"
DEVICE_ARG="${2:-}"

printf "${BLUE}📄 Using environment file: %s${NC}\n" "$ENV_FILE"

if [ ! -f "$ENV_FILE" ]; then
  printf "${RED}❌ File '%s' not found.${NC}\n" "$ENV_FILE"
  printf "\nCreate one — example:\n"
  printf "  API_URL=http://10.0.2.2:8080   # Android emulator\n"
  printf "  API_URL=http://localhost:8080   # iOS simulator\n"
  exit 1
fi

# Load env vars (compatible with bash and zsh)
set -o allexport
# shellcheck disable=SC1090
. "$ENV_FILE"
set +o allexport

API_URL="${API_URL:-http://10.0.2.2:8080}"

# Health check (non-blocking)
HEALTH_URL="${API_URL}/health"
printf "${BLUE}🔗 Pinging backend: %s${NC}\n" "$HEALTH_URL"
if curl -sf --max-time 3 "$HEALTH_URL" > /dev/null 2>&1; then
  printf "${GREEN}✅ Backend is reachable${NC}\n"
else
  printf "${YELLOW}⚠️  Backend not reachable — continuing anyway${NC}\n"
  printf "   Start with: ./run-api.sh up -d\n"
fi

printf "${BLUE}📦 flutter pub get...${NC}\n"
cd "$(dirname "$0")/app"
flutter pub get

# Device selection
if [ -z "$DEVICE_ARG" ]; then
  DEVICE_COUNT=$(flutter devices 2>/dev/null | grep -c 'mobile\|desktop\|emulator' || true)
  if [ "$DEVICE_COUNT" -gt 1 ]; then
    printf "\n${YELLOW}Multiple devices found:${NC}\n"
    flutter devices 2>/dev/null | grep '•' | awk -F'•' '{print NR". "$1"•"$2}' | head -10
    printf "\n${YELLOW}Pass a device ID as the second arg, e.g.:${NC}\n"
    printf "  %s %s emulator-5554\n\n" "$0" "$ENV_FILE"
  fi
  DEVICE_FLAG=""
else
  DEVICE_FLAG="-d $DEVICE_ARG"
fi

printf "\n${GREEN}🚀 Launching Remembite...${NC}\n"
printf "   API_URL → %s\n\n" "$API_URL"
printf "  r  hot reload    R  hot restart    q  quit\n\n"

# shellcheck disable=SC2086
flutter run $DEVICE_FLAG \
  --dart-define=API_URL="$API_URL"

printf "${GREEN}✅ Session ended.${NC}\n"
