#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${LAZYAI_BIN:-$ROOT/dist/lazyai}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
WORK="$TMP/work"
mkdir -p "$WORK" "$TMP/home" "$TMP/empty-bin" "$TMP/claude/project" \
  "$TMP/codex/sessions/2026/08/02" "$TMP/agy/conversations" "$TMP/agy/cache"

cat >"$TMP/claude/project/claude-1.jsonl" <<JSON
{"type":"user","cwd":"$WORK"}
{"type":"custom-title","customTitle":"Claude session"}
JSON
cat >"$TMP/codex/sessions/2026/08/02/rollout.jsonl" <<JSON
{"type":"session_meta","payload":{"id":"codex-1","cwd":"$WORK"}}
{"type":"response_item","payload":{"role":"user","content":[{"type":"input_text","text":"Codex session"}]}}
JSON
printf '\012\013AGY session' >"$TMP/agy/conversations/agy-1.pb"
printf '{"%s":"agy-1"}\n' "$WORK" >"$TMP/agy/cache/last_conversations.json"

export HOME="$TMP/home" CLAUDE_PROJECTS="$TMP/claude" CODEX_HOME="$TMP/codex" AGY_HOME="$TMP/agy"
export XDG_CONFIG_HOME="$HOME/.config"
export LAZYAI_CONFIG="$HOME/.config/lazyai/config.toml"
base_path="/usr/bin:/bin"

reset_config() { rm -f "$HOME/.config/lazyai/config.toml"; }
fake_path() {
  local dir="$TMP/path-$1"; rm -rf "$dir"; mkdir -p "$dir"
  shift
  for cli in "$@"; do printf '#!/bin/sh\nexit 0\n' >"$dir/$cli"; chmod +x "$dir/$cli"; done
  printf '%s:%s' "$dir" "$base_path"
}
expect_output() {
  local expected="$1"; shift
  "$@" | grep -F "$expected" >/dev/null
}
expect_failure() {
  local expected="$1" outfile="$TMP/failure"; shift
  if "$@" >"$outfile" 2>&1; then echo "unexpected success: $*" >&2; exit 1; fi
  grep -F "$expected" "$outfile" >/dev/null
}

# 0 installed: onboarding, even though historical session stores exist.
reset_config
expect_failure 'No supported AI coding CLI is installed.' env PATH="$TMP/empty-bin:$base_path" "$BIN"

# Exactly one installed: use it regardless of the fresh-install AGY preference.
reset_config
expect_output 'claude --resume claude-1' env PATH="$(fake_path claude claude)" LAZYAI_DRYRUN=1 "$BIN" 1
reset_config
expect_output 'codex resume codex-1' env PATH="$(fake_path codex codex)" LAZYAI_DRYRUN=1 "$BIN" 1
reset_config
expect_output 'agy --conversation agy-1' env PATH="$(fake_path agy agy)" LAZYAI_DRYRUN=1 "$BIN" 1

# Multiple installed: AGY wins when available; Claude+Codex needs an explicit choice in non-TTY tests.
reset_config
expect_output 'agy --conversation agy-1' env PATH="$(fake_path agy-claude agy claude)" LAZYAI_DRYRUN=1 "$BIN" 1
reset_config
expect_failure 'Multiple backends are installed; specify one or set a default.' \
  env PATH="$(fake_path claude-codex claude codex)" LAZYAI_DRYRUN=1 "$BIN" 1
reset_config
expect_output 'agy --conversation agy-1' env PATH="$(fake_path all agy claude codex)" LAZYAI_DRYRUN=1 "$BIN" 1

# Setting a default validates the executable and never corrupts the old setting.
reset_config
expect_failure 'Cannot set default to codex: codex is not installed or not on PATH.' \
  env PATH="$TMP/empty-bin:$base_path" "$BIN" default codex
[ ! -e "$HOME/.config/lazyai/config.toml" ]
env PATH="$(fake_path set-codex codex)" "$BIN" default codex >/dev/null
grep -F 'default = "codex"' "$HOME/.config/lazyai/config.toml" >/dev/null

# An explicitly configured backend that later disappears must not silently fall back.
expect_failure 'Configured default backend "codex" is unavailable.' \
  env PATH="$(fake_path lost-default agy claude)" LAZYAI_DRYRUN=1 "$BIN" 1

# Sessions-only supports read-only listing, but resume checks the missing executable.
expect_output '[Codex session]' env PATH="$TMP/empty-bin:$base_path" "$BIN" codex -l
expect_failure 'Cannot resume: codex is not installed or not on PATH.' \
  env PATH="$TMP/empty-bin:$base_path" "$BIN" codex 1

# Sourced shell integration must perform the same pre-resume check instead of
# falling through to a generic `command not found` error.
ln -s "$BIN" "$TMP/empty-bin/lazyai"
if PATH="$TMP/empty-bin:$base_path" bash -c \
  'source "$1/lazyaicli.sh"; source "$1/cxs.sh"; cxs 1' _ "$ROOT" \
  >"$TMP/sourced-missing" 2>&1; then
  echo 'sourced missing backend unexpectedly succeeded' >&2; exit 1
fi
grep -F 'Cannot resume: codex is not installed or not on PATH.' "$TMP/sourced-missing" >/dev/null

echo 'backend detection tests passed'
