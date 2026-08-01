#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/work" "$TMP/codex/sessions/2026/08/01" "$TMP/claude/project" \
  "$TMP/agy/conversations" "$TMP/agy/cache"

cat > "$TMP/codex/sessions/2026/08/01/rollout-test.jsonl" <<JSON
{"type":"session_meta","payload":{"id":"codex-123","cwd":"$TMP/work"}}
{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<environment_context>injected</environment_context>"}]}}
{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"Fix the Codex picker"}]}}
JSON

cat > "$TMP/claude/project/claude-123.jsonl" <<JSON
{"type":"user","cwd":"$TMP/work"}
{"type":"custom-title","customTitle":"Claude picker"}
{"type":"last-prompt","lastPrompt":"keep the launch cwd"}
JSON

printf '{"%s":"agy-123"}\n' "$TMP/work" > "$TMP/agy/cache/last_conversations.json"
uv run --no-project python - "$TMP/agy/conversations/agy-123.db" <<'PY'
import sqlite3, sys
db = sqlite3.connect(sys.argv[1])
db.execute("CREATE TABLE steps (idx INTEGER, step_payload BLOB)")
db.execute("INSERT INTO steps VALUES (0, ?)", (b"Improve the Antigravity picker workflow",))
db.commit()
PY

export LAZYAICLI_LANG=en
CODEX_HOME="$TMP/codex" "$ROOT/bin/cxs" -l | grep -F '[Fix the Codex picker]'
CXS_DRYRUN=1 CODEX_HOME="$TMP/codex" "$ROOT/bin/cxs" 1 | grep -F 'codex resume codex-123'
CXS_DRYRUN=1 CODEX_HOME="$TMP/codex" "$ROOT/bin/cxs" '[' | grep -F 'codex resume codex-123'
CLAUDE_PROJECTS="$TMP/claude" "$ROOT/bin/ccs" -l | grep -F '[Claude picker]'
CCS_DRYRUN=1 CLAUDE_PROJECTS="$TMP/claude" "$ROOT/bin/ccs" 1 | grep -F 'claude --resume claude-123'
AGY_HOME="$TMP/agy" "$ROOT/bin/ags" -l | grep -F '[Improve the Antigravity picker workflow]'
AGS_DRYRUN=1 AGY_HOME="$TMP/agy" "$ROOT/bin/ags" 1 | grep -F 'agy --conversation agy-123'

HOME="$TMP/home" SHELL=/bin/bash ACS_DIR="$ROOT" CCS_BIN_DIR="$TMP/home/.local/bin" \
  bash "$ROOT/install.sh" >/dev/null
grep -F 'export PATH=' "$TMP/home/.bashrc"
test -L "$TMP/home/.local/bin/ccs"
test -L "$TMP/home/.local/bin/ags"
test -L "$TMP/home/.local/bin/cxs"

echo 'smoke tests passed'
