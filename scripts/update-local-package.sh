#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$ROOT/Packaging/VERSION"

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "missing version file: $VERSION_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$VERSION_FILE"
: "${ROSTER_MARKETING_VERSION:?missing ROSTER_MARKETING_VERSION in $VERSION_FILE}"
: "${ROSTER_BUILD_NUMBER:?missing ROSTER_BUILD_NUMBER in $VERSION_FILE}"

NEXT_BUILD_NUMBER=$((ROSTER_BUILD_NUMBER + 1))
TMP_VERSION_FILE="$(mktemp "$ROOT/Packaging/VERSION.XXXXXX")"
trap 'rm -f "$TMP_VERSION_FILE"' EXIT

cat >"$TMP_VERSION_FILE" <<EOF
ROSTER_MARKETING_VERSION=$ROSTER_MARKETING_VERSION
ROSTER_BUILD_NUMBER=$NEXT_BUILD_NUMBER
EOF

mv "$TMP_VERSION_FILE" "$VERSION_FILE"
trap - EXIT

echo "updated Packaging/VERSION to build $NEXT_BUILD_NUMBER"
killall Bearoster >/dev/null 2>&1 || true
killall Roster >/dev/null 2>&1 || true
BUILD_OUTPUT="$("$ROOT/scripts/build-app.sh" release)"
APP_PATH="${BUILD_OUTPUT##*$'\n'}"
TARGET_APP="/Applications/Bearoster.app"
LEGACY_ROSTER_APP="/Applications/Roster.app"
LEGACY_BIRTHDAY_APP="/Applications/Birthday.app"
rm -rf "$TARGET_APP"
cp -R "$APP_PATH" "$TARGET_APP"
rm -rf "$LEGACY_ROSTER_APP" "$LEGACY_BIRTHDAY_APP"
echo "installed $TARGET_APP"
open "$TARGET_APP"
