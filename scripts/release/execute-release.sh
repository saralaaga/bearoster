#!/usr/bin/env bash
# Gate + privileged-step boundary for a Bearoster release action.
#
#   scripts/release/execute-release.sh \
#     --manifest release/artifacts/<commit>/manifest.txt \
#     --action submit-for-review \
#     --target app-store-connect
#
# Runs the full approval gate, then stops. The privileged sign/upload step is
# intentionally unimplemented while no verified independent approval channel
# exists — see docs/release-protected-executor.md.

set -euo pipefail

# shellcheck source=lib-release.sh
source "$(cd "$(dirname "$0")" && pwd)/lib-release.sh"

MANIFEST=""
ACTION=""
TARGET=""
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --manifest) MANIFEST="${2:-}"; shift 2 ;;
    --action) ACTION="${2:-}"; shift 2 ;;
    --target) TARGET="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$MANIFEST" ] || die "--manifest is required"
[ -n "$ACTION" ] || die "--action is required"
[ -n "$TARGET" ] || die "--target is required"

info "release gate version $RELEASE_GATE_VERSION (policy $RELEASE_POLICY_VERSION)"

"$(dirname "$0")/verify-approval.sh" \
  --manifest "$MANIFEST" --action "$ACTION" --target "$TARGET" >/dev/null

info "gate passed for action=$ACTION target=$TARGET"

cat >&2 <<EOF

Would now run the privileged step:
  target      $TARGET
  action      $ACTION
  manifest    $MANIFEST
  identity    Apple Distribution / Mac Installer Distribution (local keychain)
  notary key  Infisical Bearoster/prod /notary

That step is not implemented on purpose.
EOF

if [ "$DRY_RUN" = "1" ]; then
  info "dry run only; nothing was signed and nothing was uploaded"
  exit 0
fi

blocked_no_channel
