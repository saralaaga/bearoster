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

# Bundle identifier. Debug keeps the long-standing dev id so existing local
# TCC/Contacts grants survive; release uses the shipping identifier.
if [[ -z "${ROSTER_BUNDLE_ID:-}" ]]; then
  if [[ "$CONFIG" == "release" ]]; then
    ROSTER_BUNDLE_ID="com.bearoster.app"
  else
    ROSTER_BUNDLE_ID="dev.local.roster"
  fi
fi

if [[ -n "${ROSTER_APP_DIR:-}" ]]; then
  APP_DIR="$ROSTER_APP_DIR"
elif [[ "$CONFIG" == "release" ]]; then
  APP_DIR="$ROOT/dist/$APP_NAME.app"
else
  APP_DIR="$ROOT/.build/$APP_NAME.app"
fi
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

export CLANG_MODULE_CACHE_PATH="$ROOT/.tmp-swift-cache"

# MAS builds compile out the loopback MCP server: App Store builds ship
# without com.apple.security.network.server (RosterAppModel and the settings
# view gate on the same flag).
SWIFT_BUILD_ARGS=(--scratch-path "$ROOT/.build" -c "$CONFIG")
if [[ "${ROSTER_MAS:-0}" == "1" ]]; then
  SWIFT_BUILD_ARGS+=(-Xswiftc -DROSTER_MAS)
  # 日历分享 2026-09-30 复审暂缓；IAP/Worker/隐私口径就绪后 ROSTER_SHARE=1 重开。
  if [[ "${ROSTER_SHARE:-0}" == "1" ]]; then
    SWIFT_BUILD_ARGS+=(-Xswiftc -DCALENDAR_SHARE_LIVE)
  fi
fi

swift build "${SWIFT_BUILD_ARGS[@]}"

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"
cp "$ROOT/.build/$CONFIG/$APP_NAME" "$MACOS/$APP_NAME"
cp "$ROOT/Packaging/Info.plist" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $ROSTER_MARKETING_VERSION" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $ROSTER_BUILD_NUMBER" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $ROSTER_BUNDLE_ID" "$CONTENTS/Info.plist"
if [[ -f "$ROOT/Packaging/AppIcon.icns" ]]; then
  cp "$ROOT/Packaging/AppIcon.icns" "$RESOURCES/AppIcon.icns"
fi
chmod +x "$MACOS/$APP_NAME"

if [[ -f "$ROOT/Packaging/PrivacyInfo.xcprivacy" ]]; then
  cp "$ROOT/Packaging/PrivacyInfo.xcprivacy" "$RESOURCES/PrivacyInfo.xcprivacy"
fi

if [[ -n "${ROSTER_EMBED_PROFILE:-}" ]]; then
  cp "$ROSTER_EMBED_PROFILE" "$CONTENTS/embedded.provisionprofile"
fi

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
    ENTITLEMENTS="${ROSTER_ENTITLEMENTS:-$ROOT/Packaging/Bearoster.entitlements}"
    if [[ -f "$ENTITLEMENTS" ]]; then
      CODESIGN_ARGS+=(--entitlements "$ENTITLEMENTS")
    fi
    # App Store packages don't need a secure timestamp (a Developer ID
    # notarization requirement); the fetch needs timestamp.apple.com, whose
    # IPv6 route is dead on this build host.
    if [[ "$SIGN_IDENTITY" != "-" && "${ROSTER_MAS:-0}" != "1" ]]; then
      CODESIGN_ARGS+=(--timestamp)
    fi
  fi
  codesign "${CODESIGN_ARGS[@]}" "$APP_DIR" >/dev/null
fi

if [[ "$CONFIG" == "release" && "${ROSTER_SKIP_ZIP:-0}" != "1" ]]; then
  (cd "$ROOT/dist" && rm -f "$APP_NAME-$ROSTER_MARKETING_VERSION.zip" && zip -qr "$APP_NAME-$ROSTER_MARKETING_VERSION.zip" "$APP_NAME.app")
  echo "$ROOT/dist/$APP_NAME-$ROSTER_MARKETING_VERSION.zip"
fi

echo "$APP_DIR"
