#!/usr/bin/env bash
# Build a release candidate from a clean tree. Holds no secrets.
#
#   scripts/release/build-release-artifact.sh [mas|direct]
#
# Produces release/artifacts/<commit>/<file> plus a manifest that binds the
# artifact to the exact commit, version and SHA-256 digest. Nothing leaves the
# machine. Signing here uses the local keychain identity only.

set -euo pipefail

# shellcheck source=lib-release.sh
source "$(cd "$(dirname "$0")" && pwd)/lib-release.sh"

KIND="${1:-mas}"
case "$KIND" in
  mas|direct) ;;
  *) die "usage: $0 [mas|direct]" ;;
esac

worktree_is_clean || die "worktree is dirty; commit or stash before building a release candidate"

COMMIT="$(head_commit)"
SHORT="${COMMIT:0:12}"
OUT_DIR="$ARTIFACT_DIR/$SHORT"
mkdir -p "$OUT_DIR"

# shellcheck disable=SC1090
source "$RELEASE_ROOT/Packaging/VERSION"
MARKETING="$ROSTER_MARKETING_VERSION"
BUILD_NUMBER="$ROSTER_BUILD_NUMBER"

info "building $KIND artifact for $SHORT (version $MARKETING ($BUILD_NUMBER))"

if [ "$KIND" = "mas" ]; then
  # build-mas-pkg.sh signs with the local Apple Distribution identity and pulls
  # the notary key from Infisical. For a *candidate* we must not touch either.
  die "the MAS path needs a signing identity and the notary key; refusing to build a candidate that would acquire release credentials. Use the trusted release context described in docs/release-protected-executor.md."
fi

# Ad-hoc only. A candidate must never pick up the release signing identity;
# signed candidates belong in the trusted release context.
ROSTER_APP_DIR="$OUT_DIR/Bearoster.app" \
ROSTER_CODESIGN_IDENTITY="-" \
ROSTER_SKIP_ZIP=1 \
  "$RELEASE_ROOT/scripts/build-app.sh" release >/dev/null

ARTIFACT="$OUT_DIR/Bearoster.app"
[ -d "$ARTIFACT" ] || die "expected $ARTIFACT"

DIGEST="$(sha256_of <(cd "$OUT_DIR" && find Bearoster.app -type f -print0 | sort -z | xargs -0 shasum -a 256))"

cat > "$OUT_DIR/$MANIFEST_NAME" <<EOF
manifest-version: 1
created-at: $(iso_now)
kind: $KIND
commit: $COMMIT
worktree-clean: true
marketing-version: $MARKETING
build-number: $BUILD_NUMBER
bundle-id: com.bearoster.app
artifact: Bearoster.app
tree-sha256: $DIGEST
EOF

info "manifest written: $OUT_DIR/$MANIFEST_NAME"
cat "$OUT_DIR/$MANIFEST_NAME"
