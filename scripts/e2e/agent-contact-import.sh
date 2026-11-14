#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# The app listens on AgentAccessServer.defaultPort (47110); there is no port override.
PORT=47110
TOKEN="e2e-secret-$(date +%s)"
URL="http://127.0.0.1:${PORT}/mcp"
CONFIRM="${1:-}"
RESPONSE="$(mktemp "${TMPDIR:-/tmp}/roster-agent-e2e.XXXXXX")"

fixture_pids() {
  # Match only the fixture instance by its unique e2e launch arguments, so the
  # user's own Bearoster/Roster processes are never touched.
  pgrep -f -- '--roster-e2e agent-import' 2>/dev/null || true
}

fail() { echo "FAIL: $*" >&2; cleanup; exit 1; }
cleanup() {
  local pids
  pids="$(fixture_pids)"
  if [ -n "$pids" ]; then
    kill $pids >/dev/null 2>&1 || true
  fi
  rm -f "$RESPONSE"
}
trap cleanup EXIT

mcp() {
  local body="$1" token="${2:-$TOKEN}"
  curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$URL" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "Authorization: Bearer ${token}" \
    --data "$body"
}

expect_contains() {
  grep -q "$1" "$RESPONSE" || fail "response missing: $1
$(cat "$RESPONSE")"
}

echo "== building debug app =="
APP_PATH="$("$ROOT/scripts/build-app.sh" debug | tail -n 1)"

echo "== launching fixture instance with agent access =="
open -n "$APP_PATH" --args --roster-e2e agent-import --agent-token "$TOKEN"

echo "== waiting for the MCP endpoint on port ${PORT} =="
READY=0
for _ in $(seq 1 60); do
  if nc -z 127.0.0.1 "$PORT" 2>/dev/null; then
    READY=1
    break
  fi
  sleep 0.5
done
[ "$READY" = "1" ] || fail "agent access endpoint never came up on port ${PORT}"

echo "== initialize =="
STATUS="$(mcp '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"e2e","version":"1.0"}}}')"
[ "$STATUS" = "200" ] || fail "initialize returned $STATUS"
expect_contains 'Bearoster'

echo "== initialized notification =="
mcp '{"jsonrpc":"2.0","method":"notifications/initialized"}' >/dev/null

echo "== tools/list =="
STATUS="$(mcp '{"jsonrpc":"2.0","id":2,"method":"tools/list"}')"
[ "$STATUS" = "200" ] || fail "tools/list returned $STATUS"
expect_contains 'queue_drafts'
expect_contains 'list_pending'

echo "== queue_drafts: valid batch =="
STATUS="$(mcp '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"queue_drafts","arguments":{"schemaVersion":1,"drafts":[{"displayName":"张伟","givenName":"伟","familyName":"张","phoneNumbers":["13800138000"],"birthdays":[{"date":"1990-08-04"}]},{"displayName":"李娜","emailAddresses":["lina@example.com"]}]}}}')"
[ "$STATUS" = "200" ] || fail "queue_drafts returned $STATUS"
expect_contains 'accepted'
expect_contains '张伟'
expect_contains '李娜'

echo "== queue_drafts: per-item rejection of unknown fields =="
STATUS="$(mcp '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"queue_drafts","arguments":{"schemaVersion":1,"drafts":[{"displayName":"王五","contactID":"hack"}]}}}')"
[ "$STATUS" = "200" ] || fail "invalid batch returned $STATUS"
expect_contains 'unknown field'
expect_contains 'rejected'

echo "== list_pending shows queued drafts =="
STATUS="$(mcp '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"list_pending","arguments":{}}}')"
[ "$STATUS" = "200" ] || fail "list_pending returned $STATUS"
expect_contains '张伟'

echo "== auth gateway rejects a bad token =="
STATUS="$(mcp '{"jsonrpc":"2.0","id":6,"method":"tools/list"}' 'wrong-token')"
[ "$STATUS" = "401" ] || fail "bad token returned $STATUS (expected 401)"

echo "== automated segment passed =="

if [ "$CONFIRM" = "--confirm" ]; then
  echo
  echo "== manual segment: real Contacts write-back =="
  echo "This creates one contact (E2E 智能体导入测试) in macOS Contacts via the app UI,"
  echo "then deletes it. Bearoster must be visible; confirm the write in Sync History."
  read -r -p "Type CREATE to continue: " answer
  [ "$answer" = "CREATE" ] || { echo "skipped manual segment"; exit 0; }

  STATUS="$(mcp '{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"queue_drafts","arguments":{"schemaVersion":1,"drafts":[{"displayName":"E2E 智能体导入测试","phoneNumbers":["13900000000"]}]}}}')"
  [ "$STATUS" = "200" ] || fail "manual queue_drafts returned $STATUS"
  echo "Draft queued. In Bearoster: Sync History → 写回待处理 (write back pending),"
  echo "then verify the contact exists in macOS Contacts."
  read -r -p "Type VERIFIED once the contact exists: " verified
  [ "$verified" = "VERIFIED" ] || fail "manual verification not confirmed"
  echo "Now delete 'E2E 智能体导入测试' from macOS Contacts, then continue."
  read -r -p "Type CLEANED once deleted: " cleaned
  [ "$cleaned" = "CLEANED" ] || fail "cleanup not confirmed"
  echo "== manual segment passed =="
fi
