#!/usr/bin/env bash
# Runs the Tadabbur app in release mode on a connected device with
# Quran Foundation OAuth credentials injected from .env via --dart-define.
#
# Usage: ./scripts/run-dev.sh
#
# Requires:
#   - .env at repo root with QF_CLIENT_ID, QF_CLIENT_SECRET, QF_AUTH_ENDPOINT
#   - A connected Android device with USB debugging enabled

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

flutter run --release \
  --dart-define=QF_CLIENT_ID="$QF_CLIENT_ID" \
  --dart-define=QF_CLIENT_SECRET="$QF_CLIENT_SECRET" \
  --dart-define=QF_AUTH_ENDPOINT="$QF_AUTH_ENDPOINT"
