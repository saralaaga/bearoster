#!/usr/bin/env bash
# HUMAN ENTRYPOINT. Do not run this as an agent or inside a credential-bearing
# build shell. It copies the Bearoster Mac App Store signing material into the
# GitHub app-store-release environment without printing any value.
#
# Inputs (defaults follow the local signing-host layout):
#   ROSTER_MAS_P12       combined Apple Distribution + Installer p12
#                        (default ~/private_keys/p12/bearoster-mas-identities.p12)
#   ROSTER_MAS_PROFILE   provisioning profile
#                        (default ~/private_keys/profile/Bearoster_Mac_App_Store.provisionprofile)
# and, prompted interactively: the p12 password, the App Store Connect API key
# id, its issuer id, and the path to the AuthKey .p8.

set -euo pipefail

REPO="saralaaga/bearoster"
ENVIRONMENT="app-store-release"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ -t 0 ] || die "human entrypoint only; refusing to run without an interactive terminal"
command -v gh >/dev/null || die "gh CLI is required"

P12="${ROSTER_MAS_P12:-$HOME/private_keys/p12/bearoster-mas-identities.p12}"
PROFILE="${ROSTER_MAS_PROFILE:-$HOME/private_keys/profile/Bearoster_Mac_App_Store.provisionprofile}"

[ -f "$P12" ] || die "missing p12: $P12 (set ROSTER_MAS_P12)"
[ -f "$PROFILE" ] || die "missing profile: $PROFILE (set ROSTER_MAS_PROFILE)"

base64 < "$P12" | gh secret set MAS_IDENTITIES_P12_B64 \
  --repo "$REPO" --env "$ENVIRONMENT"
base64 < "$PROFILE" | gh secret set MAS_PROVISIONING_PROFILE_B64 \
  --repo "$REPO" --env "$ENVIRONMENT"

printf 'p12 password: ' >&2
read -rs P12_PASSWORD
printf '\n' >&2
[ -n "$P12_PASSWORD" ] || die "empty p12 password"
printf '%s' "$P12_PASSWORD" | gh secret set MAS_P12_PASSWORD \
  --repo "$REPO" --env "$ENVIRONMENT"
unset P12_PASSWORD

printf 'App Store Connect API key id: ' >&2
read -rs ASC_KEY_ID
printf '\n' >&2
[ -n "$ASC_KEY_ID" ] || die "empty API key id"
printf '%s' "$ASC_KEY_ID" | gh secret set ASC_API_KEY_ID \
  --repo "$REPO" --env "$ENVIRONMENT"

printf 'App Store Connect issuer id: ' >&2
read -rs ASC_ISSUER_ID
printf '\n' >&2
[ -n "$ASC_ISSUER_ID" ] || die "empty issuer id"
printf '%s' "$ASC_ISSUER_ID" | gh secret set ASC_API_ISSUER_ID \
  --repo "$REPO" --env "$ENVIRONMENT"

printf 'Path to the AuthKey .p8: ' >&2
read -r P8_PATH
[ -f "$P8_PATH" ] || die "no such file: $P8_PATH"
base64 < "$P8_PATH" | gh secret set ASC_API_KEY_P8_B64 \
  --repo "$REPO" --env "$ENVIRONMENT"

unset ASC_KEY_ID ASC_ISSUER_ID

printf 'GitHub environment secrets updated: MAS_IDENTITIES_P12_B64, MAS_PROVISIONING_PROFILE_B64, MAS_P12_PASSWORD, ASC_API_KEY_ID, ASC_API_ISSUER_ID, ASC_API_KEY_P8_B64\n'
