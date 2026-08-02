#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${LAZYAI_BIN:-$ROOT/dist/lazyai}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/home" "$TMP/bin" "$TMP/claude/empty" "$TMP/codex/sessions/2026/08/02" \
  "$TMP/agy/conversations" "$TMP/agy/cache" "$TMP/work"
export HOME="$TMP/home" CLAUDE_PROJECTS="$TMP/claude" CODEX_HOME="$TMP/codex" AGY_HOME="$TMP/agy"
export XDG_CONFIG_HOME="$HOME/.config"

printf '\012\013AGY session' >"$TMP/agy/conversations/agy-edge.pb"
printf '{"%s":"agy-edge"}\n' "$TMP/work" >"$TMP/agy/cache/last_conversations.json"
cat >"$TMP/codex/sessions/2026/08/02/valid.jsonl" <<JSON
{"type":"session_meta","payload":{"id":"codex-edge","cwd":"$TMP/work"}}
{"type":"response_item","payload":{"role":"user","content":[{"type":"input_text","text":"Valid despite corrupt neighbor"}]}}
JSON
printf 'not json\n{broken' >"$TMP/codex/sessions/2026/08/02/corrupt.jsonl"
printf '#!/bin/sh\nexit 0\n' >"$TMP/bin/claude"
printf '#!/bin/sh\nexit 0\n' >"$TMP/bin/codex"
chmod +x "$TMP/bin/claude" "$TMP/bin/codex"
printf '#!/bin/sh\nexit 0\n' >"$TMP/bin/agy" # deliberately not executable
export PATH="$TMP/bin:/usr/bin:/bin"

doctor="$($BIN doctor)"
grep -E 'agy[[:space:]]+sessions-only[[:space:]]+1' <<<"$doctor" >/dev/null
grep -E 'claude[[:space:]]+installed-empty[[:space:]]+0' <<<"$doctor" >/dev/null
grep -E 'codex[[:space:]]+ready[[:space:]]+1' <<<"$doctor" >/dev/null

# One damaged file must not hide healthy sessions.
$BIN codex -l | grep -F '[Valid despite corrupt neighbor]' >/dev/null

# Unknown or malformed config is reported and never overwritten implicitly.
mkdir -p "$HOME/.config/lazyai"
printf 'default = "unknown"\n' >"$HOME/.config/lazyai/config.toml"
if $BIN >"$TMP/config-error" 2>&1; then exit 1; fi
grep -F 'unknown backend in config: unknown' "$TMP/config-error" >/dev/null

# A vanished session cwd must fail clearly before launching the backend.
printf 'default = "codex"\n' >"$HOME/.config/lazyai/config.toml"
sed -e "s#$TMP/work#$TMP/missing-work#" -e 's/codex-edge/codex-missing/' \
  -e 's/Valid despite corrupt neighbor/Missing cwd/' \
  "$TMP/codex/sessions/2026/08/02/valid.jsonl" >"$TMP/codex/sessions/2026/08/02/missing.jsonl"
touch -r "$TMP/codex/sessions/2026/08/02/valid.jsonl" "$TMP/codex/sessions/2026/08/02/missing.jsonl"
if $BIN codex missing >"$TMP/cwd-error" 2>&1; then exit 1; fi
grep -F 'session directory:' "$TMP/cwd-error" >/dev/null

echo 'edge case tests passed'
