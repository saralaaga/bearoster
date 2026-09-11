#!/usr/bin/env bash
#
# Build a Mac App Store installer package (.pkg) for Bearoster.
#
# Signs the app with the sandbox entitlements merged from the provisioning
# profile, embeds the profile, then wraps the bundle in a signed .pkg.
#
# Requires in the login keychain:
#   - "Apple Distribution: ..."                    (signs the app)
#   - "3rd Party Mac Developer Installer: ..."     (signs the package)
#
# Environment overrides:
#   ROSTER_BUNDLE_ID                default com.bearoster.app
#   ROSTER_MAS_PROFILE              default ~/private_keys/profile/Bearoster_Mac_App_Store.provisionprofile
#   ROSTER_MAS_IDENTITY             default: first "Apple Distribution" in the keychain
#   ROSTER_MAS_INSTALLER_IDENTITY   default: first "3rd Party Mac Developer Installer" in the keychain
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Bearoster"
BUNDLE_ID="${ROSTER_BUNDLE_ID:-com.bearoster.app}"
PROFILE="${ROSTER_MAS_PROFILE:-$HOME/private_keys/profile/Bearoster_Mac_App_Store.provisionprofile}"
BASE_ENTITLEMENTS="$ROOT/Packaging/Bearoster-MAS.entitlements"
OUT_DIR="$ROOT/dist/mas"

die() { echo "error: $*" >&2; exit 1; }

[[ -f "$PROFILE" ]] || die "missing provisioning profile: $PROFILE"
[[ -f "$BASE_ENTITLEMENTS" ]] || die "missing $BASE_ENTITLEMENTS"
command -v productbuild >/dev/null || die "productbuild not found (install Xcode command line tools)"

APP_IDENTITY="${ROSTER_MAS_IDENTITY:-$(
  security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Apple Distribution: .*\)".*/\1/p' | head -1
)}"
INSTALLER_IDENTITY="${ROSTER_MAS_INSTALLER_IDENTITY:-$(
  security find-identity -v 2>/dev/null \
    | sed -n 's/.*"\(3rd Party Mac Developer Installer: .*\)".*/\1/p' | head -1
)}"
[[ -n "$APP_IDENTITY" ]] || die "no 'Apple Distribution' identity in the keychain"
[[ -n "$INSTALLER_IDENTITY" ]] || die "no '3rd Party Mac Developer Installer' identity in the keychain"

# shellcheck disable=SC1090
source "$ROOT/Packaging/VERSION"
: "${ROSTER_MARKETING_VERSION:?missing ROSTER_MARKETING_VERSION}"

STAGE="$(mktemp -d)"
chmod 700 "$STAGE"
trap 'rm -rf "$STAGE"' EXIT

echo "==> merging entitlements from the provisioning profile"
security cms -D -i "$PROFILE" > "$STAGE/profile.plist"
MERGED="$STAGE/entitlements.plist"
python3 - "$STAGE/profile.plist" "$BASE_ENTITLEMENTS" "$MERGED" <<'PY'
import plistlib, sys
profile_path, base_path, out_path = sys.argv[1:4]
with open(profile_path, "rb") as fh:
    profile = plistlib.load(fh)
with open(base_path, "rb") as fh:
    entitlements = plistlib.load(fh)
entitlements.update(profile.get("Entitlements", {}))
with open(out_path, "wb") as fh:
    plistlib.dump(entitlements, fh)
for key in sorted(entitlements):
    print(f"    {key}")
PY

APP_DIR="$STAGE/$APP_NAME.app"

echo "==> building and signing app ($BUNDLE_ID)"
ROSTER_BUNDLE_ID="$BUNDLE_ID" \
ROSTER_CODESIGN_IDENTITY="$APP_IDENTITY" \
ROSTER_ENTITLEMENTS="$MERGED" \
ROSTER_EMBED_PROFILE="$PROFILE" \
ROSTER_APP_DIR="$APP_DIR" \
ROSTER_SKIP_ZIP=1 \
  "$ROOT/scripts/build-app.sh" release > /dev/null

echo "==> verifying app"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"
codesign -d --entitlements - "$APP_DIR" 2>/dev/null \
  | grep -q 'com.apple.security.app-sandbox' \
  || die "app signature is missing the sandbox entitlement"
[[ -f "$APP_DIR/Contents/embedded.provisionprofile" ]] || die "provisioning profile was not embedded"

mkdir -p "$OUT_DIR"
PKG="$OUT_DIR/$APP_NAME-$ROSTER_MARKETING_VERSION.pkg"
rm -f "$PKG"

echo "==> building installer package"
productbuild --component "$APP_DIR" /Applications --sign "$INSTALLER_IDENTITY" "$PKG"

echo "==> verifying package"
pkgutil --check-signature "$PKG"

echo
echo "done: $PKG"
