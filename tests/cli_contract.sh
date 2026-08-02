#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${LAZYAI_BIN:-$ROOT/dist/lazyai}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
[ -x "$BIN" ] || fail "missing executable: $BIN"

help="$($BIN --help)"
while IFS= read -r line; do
  [ -z "$line" ] || grep -F -- "$line" "$ROOT/README.md" >/dev/null || fail "README is missing help line: $line"
done <<<"$help"
for text in \
  'lazyai — browse and resume AI coding sessions' \
  'lazyai [backend] [query]' \
  'lazyai default [backend]' \
  'lazyai list' \
  'lazyai doctor' \
  'agy       Antigravity sessions (default)' \
  'ccs                    Same as: lazyai claude' \
  'ags                    Same as: lazyai agy' \
  'cxs                    Same as: lazyai codex'
do
  grep -F "$text" <<<"$help" >/dev/null || fail "help is missing: $text"
done

export HOME="$TMP/home"
export XDG_CONFIG_HOME="$HOME/.config"
mkdir -p "$HOME" "$TMP/bin"
printf '#!/bin/sh\nexit 0\n' >"$TMP/bin/codex"
chmod +x "$TMP/bin/codex"
export PATH="$TMP/bin:/usr/bin:/bin"

[ "$($BIN default)" = 'agy' ] || fail 'fresh default must be agy'
$BIN default codex | grep -F 'Default backend: codex' >/dev/null
[ "$($BIN default)" = 'codex' ] || fail 'saved default must be codex'
grep -F 'default = "codex"' "$HOME/.config/lazyai/config.toml" >/dev/null

if $BIN default invalid >"$TMP/invalid.out" 2>&1; then
  fail 'invalid backend unexpectedly succeeded'
fi
grep -F 'unknown backend: invalid' "$TMP/invalid.out" >/dev/null

echo 'cli contract tests passed'
