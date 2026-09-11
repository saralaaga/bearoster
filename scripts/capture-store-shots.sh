#!/usr/bin/env bash
# Capture App Store screenshots for Bearoster.
#
# Renders the debug build with the deterministic `store` fixture (fictional
# demo data — never the user's real Contacts), resizes the window to an
# App Store-legal 1280x800 point frame, captures just that window and flattens
# the alpha corners onto white.
#
# Requires Screen Recording + Accessibility permission for the calling process.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/.build/Bearoster.app"
OUT="$ROOT/AppStore/screenshots"
TOOL="$ROOT/scripts/store-shot-tool.swift"
SHOT_TOOL=(swift "$TOOL")

WIDTH=1280
HEIGHT=800
ORIGIN_X=120
ORIGIN_Y=60

VIEWS=(
  "01-calendar:calendar"
  "02-birthdays:list"
  "03-contacts:contacts"
  "04-tags:tags"
  "05-settings:permissions"
  "06-sync-history:sync"
)

mkdir -p "$OUT"

if [[ ! -d "$APP" ]]; then
  echo "building debug app bundle…" >&2
  ROSTER_CODESIGN_IDENTITY=- "$ROOT/scripts/build-app.sh" debug >/dev/null
fi

quit_bearoster() {
  osascript -e 'tell application "Bearoster" to quit' >/dev/null 2>&1 || true
  sleep 1
  pkill -x Bearoster >/dev/null 2>&1 || true
  sleep 1
}

for entry in "${VIEWS[@]}"; do
  slug="${entry%%:*}"
  view="${entry##*:}"
  tmp="$(mktemp -t bearoster-shot)"

  quit_bearoster
  open -n "$APP" --args --roster-e2e store "$view"

  for _ in $(seq 1 60); do
    if osascript -e 'tell application "System Events" to (name of processes) contains "Bearoster"' 2>/dev/null | grep -q true; then
      break
    fi
    sleep 0.25
  done
  sleep 2.5

  osascript <<APPLESCRIPT >/dev/null
tell application "System Events"
  tell process "Bearoster"
    set frontmost to true
    repeat 40 times
      if (count of windows) > 0 then exit repeat
      delay 0.25
    end repeat
    set position of window 1 to {$ORIGIN_X, $ORIGIN_Y}
    set size of window 1 to {$WIDTH, $HEIGHT}
  end tell
end tell
APPLESCRIPT
  sleep 1.8

  window_id="$("${SHOT_TOOL[@]}" window-id Bearoster)"
  screencapture -x -o -l"$window_id" "$tmp.png"
  "${SHOT_TOOL[@]}" flatten "$tmp.png" "$OUT/$slug.png"
  rm -f "$tmp" "$tmp.png"

  printf '%-24s %s\n' "$slug" "$(sips -g pixelWidth -g pixelHeight "$OUT/$slug.png" | awk '/pixel/{printf "%s ", $2}')"
done

quit_bearoster
echo "screenshots written to $OUT"
