#!/usr/bin/env bash
# Builds a signed release APK with Quran Foundation OAuth credentials
# injected from .env via --dart-define. Output lands at:
#   build/app/outputs/flutter-apk/app-release.apk
#
# Usage: ./scripts/build-apk.sh
#
# After the build you can install via:
#   adb install -r build/app/outputs/flutter-apk/app-release.apk
#
# Install WITHOUT attaching flutter run so Samsung doesn't force-stop
# the app when the debugger detaches (which kills scheduled alarms).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if [ ! -f .env ]; then
  echo "error: .env not found at $REPO_ROOT/.env" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

: "${QF_CLIENT_ID:?QF_CLIENT_ID missing from .env}"
: "${QF_CLIENT_SECRET:?QF_CLIENT_SECRET missing from .env}"
: "${QF_AUTH_ENDPOINT:?QF_AUTH_ENDPOINT missing from .env}"

echo "Building release APK..."
# QF_USER_API_BASE is optional in pre-live (default is the prelive host).
# Set it in .env for production cutover:
#   QF_USER_API_BASE=https://apis.quran.foundation/auth
DEFINES=(
  --dart-define=QF_CLIENT_ID="$QF_CLIENT_ID"
  --dart-define=QF_CLIENT_SECRET="$QF_CLIENT_SECRET"
  --dart-define=QF_AUTH_ENDPOINT="$QF_AUTH_ENDPOINT"
)
if [ -n "${QF_USER_API_BASE:-}" ]; then
  DEFINES+=(--dart-define=QF_USER_API_BASE="$QF_USER_API_BASE")
fi

flutter build apk --release "${DEFINES[@]}"

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_PATH" ]; then
  echo ""
  echo "APK built: $APK_PATH"
  echo "Size: $(du -h "$APK_PATH" | cut -f1)"
  echo ""
  echo "Install without flutter run (to test Samsung alarm delivery):"
  echo "  adb install -r $APK_PATH"
else
  echo "error: expected APK not found at $APK_PATH" >&2
  exit 1
fi
