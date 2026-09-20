#!/usr/bin/env bash
# HUMAN ENTRYPOINT. Do not run this as an agent or inside a credential-bearing
# build shell. It copies two named values from local Infisical into the GitHub
# website-production environment without printing either value.

set -euo pipefail

REPO="saralaaga/bearoster"
ENVIRONMENT="website-production"
PROJECT_ID="c84d1d9c-75c1-4d1e-8bea-46fffb02a665"
INFISICAL_ENV="prod"
TOKEN_NAME="${1:-CLOUDFLARE_API_TOKEN}"
ACCOUNT_NAME="${2:-CLOUDFLARE_ACCOUNT_ID}"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ -t 0 ] || die "human entrypoint only; refusing to run without an interactive terminal"
command -v infisical >/dev/null || die "infisical CLI is required"
command -v gh >/dev/null || die "gh CLI is required"

for name in "$TOKEN_NAME" "$ACCOUNT_NAME"; do
  infisical secrets get "$name" \
    --projectId "$PROJECT_ID" \
    --env "$INFISICAL_ENV" \
    --silent \
    --expand=false >/dev/null || die "Infisical does not contain $name"
done

account_id="$(infisical secrets get "$ACCOUNT_NAME" \
  --projectId "$PROJECT_ID" \
  --env "$INFISICAL_ENV" \
  --silent \
  --plain \
  --expand=false)"
[[ "$account_id" =~ ^[0-9a-fA-F]{32}$ ]] || die "$ACCOUNT_NAME is not a Cloudflare account id"
unset account_id

token="$(infisical secrets get "$TOKEN_NAME" \
  --projectId "$PROJECT_ID" \
  --env "$INFISICAL_ENV" \
  --silent \
  --plain \
  --expand=false)"
[[ -n "$token" ]] || die "$TOKEN_NAME is empty"
printf '%s' "$token" | gh secret set "$TOKEN_NAME" \
  --repo "$REPO" \
  --env "$ENVIRONMENT"
unset token

account_id="$(infisical secrets get "$ACCOUNT_NAME" \
  --projectId "$PROJECT_ID" \
  --env "$INFISICAL_ENV" \
  --silent \
  --plain \
  --expand=false)"
printf '%s' "$account_id" | gh secret set "$ACCOUNT_NAME" \
  --repo "$REPO" \
  --env "$ENVIRONMENT"
unset account_id

printf 'GitHub environment secrets updated: %s, %s\n' "$TOKEN_NAME" "$ACCOUNT_NAME"
