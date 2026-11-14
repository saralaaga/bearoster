# Agent Contact Import (MCP) E2E

Roster ships an in-process MCP server (loopback only, bearer token) that lets
external agents queue contact drafts. Writing to macOS Contacts stays behind
the user's write-back confirmation. This e2e covers the automated segment:
handshake, tool discovery, validation, queueing, and the auth gateway.

## Scope

- Launch: `--roster-e2e agent-import --agent-token <secret>` (debug builds only).
- Journal isolation: fixture mode redirects `contact-journal.sqlite3` to a temp
  file, so the user's real journal and settings are never touched.
- Checks:
  - `initialize` returns server info `Bearoster`.
  - `tools/list` exposes exactly `queue_drafts` and `list_pending`.
  - A valid batch queues as pending `.create` operations (`list_pending`).
  - An invalid item (unknown field) is rejected per item, not silently queued.
  - A wrong bearer token gets HTTP 401.
- Manual segment (real Contacts write): run with `--confirm`. The script asks
  before creating one test contact and removes it afterwards. Never runs
  unattended.

## Run

```bash
scripts/e2e/agent-contact-import.sh           # automated segment only
scripts/e2e/agent-contact-import.sh --confirm # plus real write-back segment
```

## Rules

- The e2e token is chosen by the script; production tokens live in the user's
  journal settings and must not appear in scripts or logs.
- The write-back segment requires explicit operator confirmation and cleanup.
- After changing intake, validation, or the MCP server, run this script before
  publishing.
