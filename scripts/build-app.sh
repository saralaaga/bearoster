#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-debug}"

if [[ "$CONFIG" != "debug" && "$CONFIG" != "release" ]]; then
  echo "usage: $0 [debug|release]" >&2
  exit 1
fi

if [[ "$CONFIG" == "release" ]]; then
  APP_DIR="$ROOT/dist/Birthday.app"
else
  APP_DIR="$ROOT/.build/Birthday.app"
fi
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

export CLANG_MODULE_CACHE_PATH="$ROOT/.tmp-swift-cache"

swift build --scratch-path "$ROOT/.build" -c "$CONFIG"

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"
cp "$ROOT/.build/$CONFIG/Birthday" "$MACOS/Birthday"
cp "$ROOT/Packaging/Info.plist" "$CONTENTS/Info.plist"
if [[ -f "$ROOT/Packaging/AppIcon.icns" ]]; then
  cp "$ROOT/Packaging/AppIcon.icns" "$RESOURCES/AppIcon.icns"
fi
chmod +x "$MACOS/Birthday"

if command -v codesign >/dev/null 2>&1; then
  SIGN_IDENTITY="${BIRTHDAY_CODESIGN_IDENTITY:-}"
  if [[ -z "$SIGN_IDENTITY" ]] && command -v security >/dev/null 2>&1; then
    SIGN_IDENTITY="$(
      security find-identity -v -p codesigning 2>/dev/null \
        | sed -n 's/.*"\(Apple Development: .*\)".*/\1/p' \
        | head -n 1
    )"
  fi
  if [[ -z "$SIGN_IDENTITY" ]]; then
    SIGN_IDENTITY="-"
  fi
  codesign --force --sign "$SIGN_IDENTITY" "$APP_DIR" >/dev/null
fi

if [[ "$CONFIG" == "release" ]]; then
  VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$CONTENTS/Info.plist")"
  (cd "$ROOT/dist" && rm -f "Birthday-$VERSION.zip" && zip -qr "Birthday-$VERSION.zip" Birthday.app)
  echo "$ROOT/dist/Birthday-$VERSION.zip"
fi

echo "$APP_DIR"
