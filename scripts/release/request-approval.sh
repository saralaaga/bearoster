#!/usr/bin/env bash
# HUMAN ENTRYPOINT. Run this yourself; an agent must not run it on your behalf.
#
#   scripts/release/request-approval.sh \
#     --artifact release/artifacts/<commit>/<file> \
#     --action submit-for-review \
#     --target app-store-connect
#
# Writes release/approvals/<timestamp>-<action>.txt. That record is the input
# the executor verifies. It refuses to run without an interactive terminal so an
# unattended agent cannot mint one by accident.

set -euo pipefail

# shellcheck source=lib-release.sh
source "$(cd "$(dirname "$0")" && pwd)/lib-release.sh"

ARTIFACT=""
ACTION=""
TARGET=""
HOURS="${ROSTER_APPROVAL_HOURS:-72}"

while [ $# -gt 0 ]; do
  case "$1" in
    --artifact) ARTIFACT="${2:-}"; shift 2 ;;
    --action) ACTION="${2:-}"; shift 2 ;;
    --target) TARGET="${2:-}"; shift 2 ;;
    --hours) HOURS="${2:-}"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$ARTIFACT" ] || die "--artifact is required"
[ -n "$ACTION" ] || die "--action is required"
[ -n "$TARGET" ] || die "--target is required"
[ -t 0 ] || die "refusing to create an approval record without an interactive terminal"
[ -e "$ARTIFACT" ] || die "artifact not found: $ARTIFACT"

MANIFEST_DIR="$(cd "$(dirname "$ARTIFACT")" && pwd)"
MANIFEST="$MANIFEST_DIR/$MANIFEST_NAME"
[ -f "$MANIFEST" ] || die "missing manifest next to artifact: $MANIFEST"

COMMIT="$(require_field commit "$MANIFEST")"
MARKETING="$(require_field marketing-version "$MANIFEST")"
ARTIFACT_NAME="$(basename "$ARTIFACT")"
DIGEST="$(require_field tree-sha256 "$MANIFEST")"

APPROVER_NAME="$(git -C "$RELEASE_ROOT" config user.name || true)"
APPROVER_EMAIL="$(git -C "$RELEASE_ROOT" config user.email || true)"
[ -n "$APPROVER_EMAIL" ] || die "set git user.email first; the record needs an approver identity"

cat >&2 <<EOF

Approval request
  action            $ACTION
  target            $TARGET
  artifact          $ARTIFACT_NAME
  marketing version $MARKETING
  commit            $COMMIT
  tree sha256       $DIGEST
  expires in        ${HOURS}h

EOF

printf 'Type the commit short SHA (%s) to approve: ' "${COMMIT:0:12}" >&2
read -r typed
[ "$typed" = "${COMMIT:0:12}" ] || die "confirmation did not match; nothing was recorded"

printf 'What did you inspect? (one line, recorded verbatim): ' >&2
read -r evidence
[ -n "$evidence" ] || die "evidence note is required"

mkdir -p "$APPROVAL_DIR"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
SLUG="$(printf '%s' "$ACTION" | tr -c 'a-zA-Z0-9._-' '-')"
RECORD="$APPROVAL_DIR/${STAMP}-${SLUG}.txt"

cat > "$RECORD" <<EOF
approval-version: 1
action: $ACTION
target: $TARGET
approver: $APPROVER_NAME <$APPROVER_EMAIL>
approved-at: $(iso_now)
expires-at: $(iso_plus_hours "$HOURS")
commit: $COMMIT
marketing-version: $MARKETING
artifact: $ARTIFACT_NAME
tree-sha256: $DIGEST
evidence: $evidence
EOF

info "approval recorded: $RECORD"
cat "$RECORD"
