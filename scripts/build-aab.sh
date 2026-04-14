#!/usr/bin/env bash
# Builds a signed release App Bundle (.aab) with Quran Foundation OAuth
# credentials injected from .env via --dart-define. AAB is the format
# Play Store requires for new releases — an .apk uploaded via Play Console
# will be rejected.
#
# Output lands at:
#   build/app/outputs/bundle/release/app-release.aab
#
# Usage: ./scripts/build-aab.sh
#
# After the build, upload the .aab to Play Console:
#   Production → Create new release → Upload → select app-release.aab

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

echo "Building release App Bundle..."
DEFINES=(
  --dart-define=QF_CLIENT_ID="$QF_CLIENT_ID"
  --dart-define=QF_CLIENT_SECRET="$QF_CLIENT_SECRET"
  --dart-define=QF_AUTH_ENDPOINT="$QF_AUTH_ENDPOINT"
)
if [ -n "${QF_USER_API_BASE:-}" ]; then
  DEFINES+=(--dart-define=QF_USER_API_BASE="$QF_USER_API_BASE")
fi

flutter build appbundle --release "${DEFINES[@]}"

AAB_PATH="build/app/outputs/bundle/release/app-release.aab"
if [ -f "$AAB_PATH" ]; then
  echo ""
  echo "AAB built: $AAB_PATH"
  echo "Size: $(du -h "$AAB_PATH" | cut -f1)"
  echo ""
  echo "Upload to Play Console:"
  echo "  https://play.google.com/console → Production → Create new release"
else
  echo "error: expected AAB not found at $AAB_PATH" >&2
  exit 1
fi
