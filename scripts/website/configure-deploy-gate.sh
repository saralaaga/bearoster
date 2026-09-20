#!/usr/bin/env bash
# HUMAN ENTRYPOINT. Creates the GitHub deployment gate used by website.yml.

set -euo pipefail

REPO="saralaaga/bearoster"
ENVIRONMENT="website-production"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ -t 0 ] || die "human entrypoint only; refusing to run without an interactive terminal"
command -v gh >/dev/null || die "gh CLI is required"

user_id="$(gh api user --jq '.id')"
[[ -n "$user_id" ]] || die "could not resolve the authenticated GitHub user"

gh api -X PUT "repos/$REPO/environments/$ENVIRONMENT" \
  --input - <<EOF
{"wait_timer":0,"reviewers":[{"id":$user_id}],"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}
EOF

existing="$(gh api "repos/$REPO/environments/$ENVIRONMENT/deployment-branch-policies" --jq '.branch_policies[].name' || true)"
if ! printf '%s\n' "$existing" | grep -Fxq main; then
  gh api -X POST "repos/$REPO/environments/$ENVIRONMENT/deployment-branch-policies" \
    --input - <<EOF
{"name":"main"}
EOF
fi

printf 'website-production gate configured for GitHub user id %s; main only\n' "$user_id"
