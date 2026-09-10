#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-debug}"
VERSION_FILE="$ROOT/Packaging/VERSION"

if [[ "$CONFIG" != "debug" && "$CONFIG" != "release" ]]; then
  echo "usage: $0 [debug|release]" >&2
  exit 1
fi

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "missing version file: $VERSION_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$VERSION_FILE"
: "${ROSTER_MARKETING_VERSION:?missing ROSTER_MARKETING_VERSION in $VERSION_FILE}"
: "${ROSTER_BUILD_NUMBER:?missing ROSTER_BUILD_NUMBER in $VERSION_FILE}"
APP_NAME="Bearoster"

if [[ "$CONFIG" == "release" ]]; then
  APP_DIR="$ROOT/dist/$APP_NAME.app"
else
  APP_DIR="$ROOT/.build/$APP_NAME.app"
fi
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

export CLANG_MODULE_CACHE_PATH="$ROOT/.tmp-swift-cache"

swift build --scratch-path "$ROOT/.build" -c "$CONFIG"

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"
cp "$ROOT/.build/$CONFIG/$APP_NAME" "$MACOS/$APP_NAME"
cp "$ROOT/Packaging/Info.plist" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $ROSTER_MARKETING_VERSION" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $ROSTER_BUILD_NUMBER" "$CONTENTS/Info.plist"
if [[ -f "$ROOT/Packaging/AppIcon.icns" ]]; then
  cp "$ROOT/Packaging/AppIcon.icns" "$RESOURCES/AppIcon.icns"
fi
chmod +x "$MACOS/$APP_NAME"

IDENTITY_LABEL="Apple Development: "
if [[ "$CONFIG" == "release" ]]; then
  IDENTITY_LABEL="Developer ID Application: "
fi

if command -v codesign >/dev/null 2>&1; then
  SIGN_IDENTITY="${ROSTER_CODESIGN_IDENTITY:-}"
  if [[ -z "$SIGN_IDENTITY" ]] && command -v security >/dev/null 2>&1; then
    SIGN_IDENTITY="$(
      security find-identity -v -p codesigning 2>/dev/null \
        | sed -n "s/.*\"\(${IDENTITY_LABEL}.*\)\".*/\1/p" \
        | head -n 1
    )"
  fi
  if [[ -z "$SIGN_IDENTITY" ]]; then
    if [[ "$CONFIG" == "release" ]]; then
      echo "error: release build needs a 'Developer ID Application' identity; install one or set ROSTER_CODESIGN_IDENTITY=- for an ad-hoc build" >&2
      exit 1
    fi
    SIGN_IDENTITY="-"
  fi

  CODESIGN_ARGS=(--force --sign "$SIGN_IDENTITY")
  if [[ "$CONFIG" == "release" ]]; then
    CODESIGN_ARGS+=(--options runtime)
    ENTITLEMENTS="$ROOT/Packaging/Bearoster.entitlements"
    if [[ -f "$ENTITLEMENTS" ]]; then
      CODESIGN_ARGS+=(--entitlements "$ENTITLEMENTS")
    fi
    if [[ "$SIGN_IDENTITY" != "-" ]]; then
      CODESIGN_ARGS+=(--timestamp)
    fi
  fi
  codesign "${CODESIGN_ARGS[@]}" "$APP_DIR" >/dev/null
fi

if [[ "$CONFIG" == "release" ]]; then
  (cd "$ROOT/dist" && rm -f "$APP_NAME-$ROSTER_MARKETING_VERSION.zip" && zip -qr "$APP_NAME-$ROSTER_MARKETING_VERSION.zip" "$APP_NAME.app")
  echo "$ROOT/dist/$APP_NAME-$ROSTER_MARKETING_VERSION.zip"
fi

echo "$APP_DIR"
