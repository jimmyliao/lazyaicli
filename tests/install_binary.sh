#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
HOME="$TMP/home" SHELL=/bin/bash LAZYAI_BINARY="$ROOT/dist/lazyai" \
  LAZYAICLI_BIN_DIR="$TMP/bin" LAZYAICLI_DIR="$TMP/share" "$ROOT/install.sh" >/dev/null
for name in lazyai lazyaicli ccs ags cxs; do
  [ -L "$TMP/bin/$name" ]
  "$TMP/bin/$name" --help >/dev/null
done
grep -F "$ROOT/lazyaicli.sh" "$TMP/home/.bashrc" >/dev/null
if grep -Eiq 'python|uv|jq|fzf' "$TMP/home/.bashrc"; then
  echo 'unexpected runtime dependency in shell setup' >&2; exit 1
fi

# A supplied or downloaded checksum is mandatory security input: mismatch must
# fail before the executable or symlinks are installed.
if HOME="$TMP/bad-home" SHELL=/bin/bash LAZYAI_BINARY="$ROOT/dist/lazyai" \
  LAZYAI_EXPECTED_SHA256=0000000000000000000000000000000000000000000000000000000000000000 \
  LAZYAICLI_BIN_DIR="$TMP/bad-bin" LAZYAICLI_DIR="$TMP/bad-share" \
  "$ROOT/install.sh" >"$TMP/bad-checksum.out" 2>&1; then
  echo 'checksum mismatch unexpectedly succeeded' >&2; exit 1
fi
grep -F 'checksum verification failed' "$TMP/bad-checksum.out" >/dev/null
[ ! -e "$TMP/bad-share/lazyai" ]

echo 'binary installer tests passed'
