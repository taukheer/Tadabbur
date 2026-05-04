#!/usr/bin/env bash
# Builds a signed release .ipa for App Store / TestFlight submission,
# with Quran Foundation OAuth credentials injected from .env via
# --dart-define. Output lands at:
#   build/ios/ipa/Tadabbur.ipa  (or .ipa with whatever name is set in
#   the Xcode project's archive settings)
#
# Prerequisites:
#   1. .env at repo root with QF_CLIENT_ID / QF_CLIENT_SECRET / QF_AUTH_ENDPOINT.
#   2. Xcode signing configured for the Runner target — open
#      ios/Runner.xcworkspace once, select the Runner project, set
#      Team = your Apple Developer team, and let Xcode manage signing
#      automatically. After that, this script can run unattended.
#
# Usage: ./scripts/build-ipa.sh
#
# Upload to App Store Connect after the build via:
#   - Xcode → Window → Organizer → select the new archive →
#     Distribute App → App Store Connect, OR
#   - the standalone Transporter app from the Mac App Store (drop the
#     .ipa onto its window).

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

echo "Building release .ipa..."
DEFINES=(
  --dart-define=QF_CLIENT_ID="$QF_CLIENT_ID"
  --dart-define=QF_CLIENT_SECRET="$QF_CLIENT_SECRET"
  --dart-define=QF_AUTH_ENDPOINT="$QF_AUTH_ENDPOINT"
)
if [ -n "${QF_USER_API_BASE:-}" ]; then
  DEFINES+=(--dart-define=QF_USER_API_BASE="$QF_USER_API_BASE")
fi

# `flutter build ipa --release` produces an unsigned archive plus an
# Xcode-exported .ipa using whatever distribution config Xcode is set
# to. With "Automatically manage signing" checked in Xcode, this
# Just Works once the team is selected.
flutter build ipa --release "${DEFINES[@]}"

IPA_DIR="build/ios/ipa"
if [ -d "$IPA_DIR" ]; then
  IPA_FILE="$(find "$IPA_DIR" -maxdepth 1 -name '*.ipa' | head -n 1)"
  if [ -n "$IPA_FILE" ]; then
    echo ""
    echo "IPA built: $IPA_FILE"
    echo "Size: $(du -h "$IPA_FILE" | cut -f1)"
    echo ""
    echo "Upload to App Store Connect:"
    echo "  1. Open Xcode → Window → Organizer (Cmd+Shift+9)"
    echo "  2. Select the latest Tadabbur archive"
    echo "  3. Click 'Distribute App' → App Store Connect → Upload"
    echo ""
    echo "  OR: drag the .ipa into the Transporter app:"
    echo "      open -a Transporter \"$IPA_FILE\""
    exit 0
  fi
fi

echo "error: expected .ipa not found under $IPA_DIR" >&2
exit 1
