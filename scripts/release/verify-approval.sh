#!/usr/bin/env bash
# Verify that a release action is covered by a valid, artifact-bound approval.
#
#   scripts/release/verify-approval.sh \
#     --manifest release/artifacts/<commit>/manifest.txt \
#     --action submit-for-review \
#     --target app-store-connect
#
# Read-only. Exit 0 = the gate passed. Exit 4 = the gate failed.

set -euo pipefail

# shellcheck source=lib-release.sh
source "$(cd "$(dirname "$0")" && pwd)/lib-release.sh"

MANIFEST=""
ACTION=""
TARGET=""

while [ $# -gt 0 ]; do
  case "$1" in
    --manifest) MANIFEST="${2:-}"; shift 2 ;;
    --action) ACTION="${2:-}"; shift 2 ;;
    --target) TARGET="${2:-}"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

fail() { printf 'gate: FAIL — %s\n' "$*" >&2; exit 4; }
pass() { printf 'gate: ok — %s\n' "$*" >&2; }

[ -n "$MANIFEST" ] || die "--manifest is required"
[ -n "$ACTION" ] || die "--action is required"
[ -n "$TARGET" ] || die "--target is required"
[ -f "$MANIFEST" ] || die "manifest not found: $MANIFEST"

MANIFEST_COMMIT="$(require_field commit "$MANIFEST")"
MANIFEST_DIGEST="$(require_field tree-sha256 "$MANIFEST")"
MANIFEST_VERSION="$(require_field marketing-version "$MANIFEST")"

worktree_is_clean || fail "worktree is dirty"

HEAD="$(head_commit)"
[ "$HEAD" = "$MANIFEST_COMMIT" ] || fail "HEAD ($HEAD) does not match manifest commit ($MANIFEST_COMMIT)"
pass "commit matches manifest"

[ -d "$APPROVAL_DIR" ] || fail "no approvals directory"

matches=()
now="$(date -u +%s)"
for record in "$APPROVAL_DIR"/*.txt; do
  [ -e "$record" ] || continue
  [ "$(field action "$record" || true)" = "$ACTION" ] || continue
  [ "$(field target "$record" || true)" = "$TARGET" ] || continue
  [ "$(field commit "$record" || true)" = "$MANIFEST_COMMIT" ] || continue
  [ "$(field tree-sha256 "$record" || true)" = "$MANIFEST_DIGEST" ] || continue

  expires="$(field expires-at "$record" || true)"
  [ -n "$expires" ] || continue
  exp_epoch="$(iso_to_epoch "$expires" || true)"
  [ -n "$exp_epoch" ] || continue
  [ "$exp_epoch" -gt "$now" ] || continue

  matches+=("$record")
done

[ "${#matches[@]}" -gt 0 ] || fail "no unexpired approval for action=$ACTION target=$TARGET commit=${MANIFEST_COMMIT:0:12} sha256=${MANIFEST_DIGEST:0:16}…"

RECORD="${matches[0]}"
[ "${#matches[@]}" -eq 1 ] || fail "${#matches[@]} approvals match; ambiguous, expected exactly one"

pass "approval found: $RECORD"
pass "approver: $(field approver "$RECORD")"
pass "expires: $(field expires-at "$RECORD")"
pass "version: $MANIFEST_VERSION"
printf '%s\n' "$RECORD"
