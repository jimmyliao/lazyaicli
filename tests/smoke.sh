#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/work" "$TMP/codex/sessions/2026/08/01" "$TMP/claude/project" \
  "$TMP/agy/conversations" "$TMP/agy/cache" "$TMP/fake-bin"

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
for cmd in ccs ags cxs; do
  "$ROOT/bin/$cmd" --help | grep -F "Usage: $cmd"
  "$ROOT/bin/$cmd" --version | grep -F "($cmd)"
done
CODEX_HOME="$TMP/codex" "$ROOT/bin/cxs" -l | grep -F '[Fix the Codex picker]'
CXS_DRYRUN=1 CODEX_HOME="$TMP/codex" "$ROOT/bin/cxs" 1 | grep -F 'codex resume codex-123'
CXS_DRYRUN=1 CODEX_HOME="$TMP/codex" "$ROOT/bin/cxs" '[' | grep -F 'codex resume codex-123'
printf '1\n' | CXS_DRYRUN=1 CODEX_HOME="$TMP/codex" "$ROOT/bin/cxs" | grep -F 'codex resume codex-123'
CLAUDE_PROJECTS="$TMP/claude" "$ROOT/bin/ccs" -l | grep -F '[Claude picker]'
CCS_DRYRUN=1 CLAUDE_PROJECTS="$TMP/claude" "$ROOT/bin/ccs" 1 | grep -F 'claude --resume claude-123'
AGY_HOME="$TMP/agy" "$ROOT/bin/ags" -l | grep -F '[Improve the Antigravity picker workflow]'
AGS_DRYRUN=1 AGY_HOME="$TMP/agy" "$ROOT/bin/ags" 1 | grep -F 'agy --conversation agy-123'

# Sourced wrappers must change the parent shell's cwd before invoking the real CLI.
for backend in codex claude agy; do
  cat > "$TMP/fake-bin/$backend" <<'SH'
#!/usr/bin/env bash
printf '%s\t%s\n' "$PWD" "$*" >> "$LAZYAICLI_CALLS"
SH
  chmod +x "$TMP/fake-bin/$backend"
done
cat > "$TMP/fake-bin/fzf" <<'SH'
#!/usr/bin/env bash
head -1
SH
chmod +x "$TMP/fake-bin/fzf"
CXS_DRYRUN=1 CODEX_HOME="$TMP/codex" PATH="$TMP/fake-bin:$PATH" "$ROOT/bin/cxs" \
  | grep -F 'codex resume codex-123'
export LAZYAICLI_CALLS="$TMP/backend-calls"
PATH="$ROOT/bin:$TMP/fake-bin:$PATH"
export PATH
export CODEX_HOME="$TMP/codex" CLAUDE_PROJECTS="$TMP/claude" AGY_HOME="$TMP/agy"
( source "$ROOT/cxs.sh"; cxs 1 )
( source "$ROOT/ccs.sh"; ccs 1 )
( source "$ROOT/ags.sh"; ags 1 )
grep -F "$TMP/work"$'\t''resume codex-123' "$LAZYAICLI_CALLS"
grep -F "$TMP/work"$'\t''--resume claude-123' "$LAZYAICLI_CALLS"
grep -F "$TMP/work"$'\t''--conversation agy-123' "$LAZYAICLI_CALLS"

HOME="$TMP/home" SHELL=/bin/bash ACS_DIR="$ROOT" CCS_BIN_DIR="$TMP/home/.local/bin" \
  bash "$ROOT/install.sh" >/dev/null
grep -F 'export PATH=' "$TMP/home/.bashrc"
test -L "$TMP/home/.local/bin/ccs"
test -L "$TMP/home/.local/bin/ags"
test -L "$TMP/home/.local/bin/cxs"

echo 'smoke tests passed'
