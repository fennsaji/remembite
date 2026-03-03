#!/usr/bin/env bash
# Remembite — Mobile App Runner
# Loads env vars, boots emulator if needed, and runs Flutter.
#
# Usage:
#   ./run-app.sh                             # default: .env.android, auto Android emulator
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

# Load env vars
set -o allexport
# shellcheck disable=SC1090
. "$ENV_FILE"
set +o allexport

API_URL="${API_URL:-http://10.0.2.2:8080}"

# ── Health check (non-blocking) ──────────────────────────────────────────
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

# ── Device / emulator selection ──────────────────────────────────────────
ANDROID_EMULATOR_ID="Pixel_3a_API_34_GooglePlay"

ensure_android_emulator() {
  # Check if an Android emulator is already running
  RUNNING=$(flutter devices 2>/dev/null | grep -i "android.*emulator\|emulator.*android" || true)
  if [ -n "$RUNNING" ]; then
    BOOT_DEVICE=$(flutter devices 2>/dev/null | grep -i "emulator-[0-9]" | awk -F'•' '{print $2}' | tr -d ' ' | head -1)
    printf "${GREEN}✅ Emulator already running: %s${NC}\n" "$BOOT_DEVICE" >&2
    echo "$BOOT_DEVICE"
    return
  fi

  printf "${BLUE}🚀 Starting Android emulator '%s'...${NC}\n" "$ANDROID_EMULATOR_ID" >&2
  flutter emulators --launch "$ANDROID_EMULATOR_ID" 2>/dev/null &

  printf "${YELLOW}⏳ Waiting for emulator to boot${NC}" >&2
  WAIT=0
  DEVICE_ID=""
  while [ $WAIT -lt 120 ]; do
    DEVICE_ID=$(adb devices 2>/dev/null | grep "emulator-" | grep -v "offline" | awk '{print $1}' | head -1 || true)
    if [ -n "$DEVICE_ID" ]; then
      BOOT_STATUS=$(adb -s "$DEVICE_ID" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)
      if [ "$BOOT_STATUS" = "1" ]; then
        printf "\n${GREEN}✅ Emulator booted: %s${NC}\n" "$DEVICE_ID" >&2
        echo "$DEVICE_ID"
        return
      fi
    fi
    printf "." >&2
    sleep 3
    WAIT=$((WAIT + 3))
  done
  printf "\n${RED}❌ Emulator did not boot within 120s${NC}\n" >&2
  exit 1
}

if [ -n "$DEVICE_ARG" ]; then
  DEVICE_FLAG="-d $DEVICE_ARG"
else
  # Determine platform from env file name
  case "$ENV_FILE" in
    *ios*)
      # iOS simulator — just let Flutter pick it (it auto-boots)
      DEVICE_FLAG=""
      ;;
    *usb*)
      # Physical USB device — set up port forwarding and use connected device
      printf "${BLUE}🔌 Setting up adb reverse for USB device...${NC}\n"
      USB_DEVICE=$(adb devices 2>/dev/null | grep -v "List of devices" | grep "device$" | grep -v "emulator" | awk '{print $1}' | head -1 || true)
      if [ -z "$USB_DEVICE" ]; then
        printf "${RED}❌ No USB device found. Enable USB debugging and reconnect.${NC}\n"
        exit 1
      fi
      adb -s "$USB_DEVICE" reverse tcp:8080 tcp:8080
      printf "${GREEN}✅ USB device ready: %s (adb reverse active)${NC}\n" "$USB_DEVICE"
      DEVICE_FLAG="-d $USB_DEVICE"
      ;;
    *)
      # Android — ensure emulator is running
      EMULATOR_ID=$(ensure_android_emulator)
      DEVICE_FLAG="-d $EMULATOR_ID"
      ;;
  esac
fi

# ── Run ──────────────────────────────────────────────────────────────────
printf "\n${GREEN}🚀 Launching Remembite...${NC}\n"
printf "   API_URL → %s\n\n" "$API_URL"
printf "  r  hot reload    R  hot restart    q  quit\n\n"

# shellcheck disable=SC2086
flutter run $DEVICE_FLAG \
  --dart-define=API_URL="$API_URL"

printf "${GREEN}✅ Session ended.${NC}\n"
