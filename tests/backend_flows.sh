#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${LAZYAI_BIN:-$ROOT/dist/lazyai}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
WORK="$TMP/work"
mkdir -p "$WORK" "$TMP/claude/project" "$TMP/codex/sessions/2026/08/02" \
  "$TMP/agy/conversations" "$TMP/agy/cache" "$TMP/bin"

cat >"$TMP/claude/project/claude-123.jsonl" <<JSON
{"type":"user","cwd":"$WORK"}
{"type":"custom-title","customTitle":"Fix Claude login"}
JSON
cat >"$TMP/codex/sessions/2026/08/02/rollout-test.jsonl" <<JSON
{"type":"session_meta","payload":{"id":"codex-123","cwd":"$WORK"}}
{"type":"response_item","payload":{"role":"user","content":[{"type":"input_text","text":"Refactor Codex picker"}]}}
JSON
# The fake legacy protobuf keeps the flow fixture dependency-free. Real SQLite
# page/record parsing is covered by Go tests and a read-only integration check.
printf '\012\040Improve the Antigravity workflow' \
  >"$TMP/agy/conversations/agy-123.pb"
printf '{"%s":"agy-123"}\n' "$WORK" >"$TMP/agy/cache/last_conversations.json"

export HOME="$TMP/home" CLAUDE_PROJECTS="$TMP/claude" CODEX_HOME="$TMP/codex" AGY_HOME="$TMP/agy"
mkdir -p "$HOME"

"$BIN" claude -l | grep -F '[Fix Claude login]'
"$BIN" codex -l | grep -F '[Refactor Codex picker]'
"$BIN" agy -l | grep -F '[Improve the Antigravity workflow]'

LAZYAI_DRYRUN=1 "$BIN" claude 1 | grep -F "claude --resume claude-123"
LAZYAI_DRYRUN=1 "$BIN" codex 1 | grep -F "codex resume codex-123"
LAZYAI_DRYRUN=1 "$BIN" agy 1 | grep -F "agy --conversation agy-123"

for link in lazyai ccs ags cxs; do ln -s "$BIN" "$TMP/bin/$link"; done
CCS_DRYRUN=1 "$TMP/bin/ccs" 1 | grep -F 'claude --resume claude-123'
CXS_DRYRUN=1 "$TMP/bin/cxs" 1 | grep -F 'codex resume codex-123'
AGS_DRYRUN=1 "$TMP/bin/ags" 1 | grep -F 'agy --conversation agy-123'

for backend in claude codex agy; do
  cat >"$TMP/bin/$backend" <<'SH'
#!/usr/bin/env bash
printf '%s\t%s\n' "$PWD" "$*" >>"$LAZYAI_CALLS"
SH
  chmod +x "$TMP/bin/$backend"
done
export LAZYAI_CALLS="$TMP/calls" PATH="$TMP/bin:$PATH"
(
  source "$ROOT/lazyaicli.sh"
  source "$ROOT/ccs.sh"
  source "$ROOT/ags.sh"
  source "$ROOT/cxs.sh"
  lazyai --help | grep -F 'lazyai default [backend]' >/dev/null
  lazyai default codex | grep -F 'Default backend: codex' >/dev/null
  ccs -l | grep -F '[Fix Claude login]' >/dev/null
  ccs 1
  cxs 1
  ags 1
)
grep -F "$WORK"$'\t''--resume claude-123' "$LAZYAI_CALLS"
grep -F "$WORK"$'\t''resume codex-123' "$LAZYAI_CALLS"
grep -F "$WORK"$'\t''--conversation agy-123' "$LAZYAI_CALLS"

echo 'backend flow tests passed'
