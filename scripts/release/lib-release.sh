#!/usr/bin/env bash
# Shared helpers for the Bearoster release gate.
#
# This gate is defense in depth. It is NOT the independent approval channel the
# deployment policy requires — see docs/release-protected-executor.md.

# shellcheck disable=SC2034
RELEASE_GATE_VERSION="1"
RELEASE_POLICY_VERSION="2026-09-06"

RELEASE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RELEASE_DIR="$RELEASE_ROOT/release"
APPROVAL_DIR="$RELEASE_DIR/approvals"
ARTIFACT_DIR="$RELEASE_DIR/artifacts"
MANIFEST_NAME="manifest.txt"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*" >&2; }

sha256_of() {
  shasum -a 256 "$1" | awk '{print $1}'
}

head_commit() {
  git -C "$RELEASE_ROOT" rev-parse HEAD
}

# `release/` holds build outputs and human approval records, not source. It is
# excluded so that minting an approval cannot itself invalidate the gate.
worktree_is_clean() {
  local dirty
  dirty="$(git -C "$RELEASE_ROOT" status --porcelain --untracked-files=normal -- . ':(exclude)release' 2>/dev/null)"
  [[ -z "$dirty" ]]
}

# field <key> <file> -> prints the value of a "key: value" line
field() {
  local key="$1" file="$2"
  [ -f "$file" ] || return 1
  awk -v k="$key" '
    index($0, k ":") == 1 {
      sub("^" k ":[[:space:]]*", "")
      print
      exit
    }
  ' "$file"
}

require_field() {
  local key="$1" file="$2" value
  value="$(field "$key" "$file" || true)"
  [ -n "$value" ] || die "missing '$key' in $file"
  printf '%s\n' "$value"
}

iso_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

iso_plus_hours() {
  local hours="$1"
  if date -u -v+"${hours}"H +%Y-%m-%dT%H:%M:%SZ >/dev/null 2>&1; then
    date -u -v+"${hours}"H +%Y-%m-%dT%H:%M:%SZ
  else
    date -u -d "+${hours} hours" +%Y-%m-%dT%H:%M:%SZ
  fi
}

iso_to_epoch() {
  local value="$1"
  date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$value" +%s 2>/dev/null \
    || date -u -d "$value" +%s
}

# The privileged step. Intentionally not implemented: wiring it up without a
# verified independent approval channel would violate the deployment policy.
blocked_no_channel() {
  cat >&2 <<'EOF'

BLOCKED: no verified independent human approval channel.

Per /Users/carlos/.agents/deployment-policy.md, a project script cannot be the
enforcement boundary, and an ordinary Agent must not hold Apple management
credentials. Until one of the entrypoints in
docs/release-protected-executor.md is built and verified, the privileged
sign/upload step stays unimplemented on purpose.

Nothing was uploaded. Nothing was signed with a release identity.
EOF
  exit 3
}
