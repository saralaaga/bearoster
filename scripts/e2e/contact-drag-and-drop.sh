#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP_PATH="$("$ROOT/scripts/build-app.sh" debug | tail -n 1)"
E2E_JXA="$ROOT/scripts/e2e/contact-drag-and-drop.jxa"

killall Roster >/dev/null 2>&1 || true
open -n "$APP_PATH" --args --roster-e2e contact-drag
osascript -l JavaScript "$E2E_JXA"
killall Roster >/dev/null 2>&1 || true
