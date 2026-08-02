#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${LAZYAICLI_DIR:-$HOME/.local/share/lazyai}"
BIN_DIR="${LAZYAICLI_BIN_DIR:-$HOME/.local/bin}"
VERSION="${LAZYAI_VERSION:-latest}"

echo "lazyai installer"
mkdir -p "$INSTALL_DIR" "$BIN_DIR"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

platform() {
  local os arch
  case "$(uname -s)" in Linux) os=linux ;; Darwin) os=darwin ;; *) echo "unsupported OS: $(uname -s)" >&2; return 1 ;; esac
  case "$(uname -m)" in x86_64|amd64) arch=amd64 ;; arm64|aarch64) arch=arm64 ;; *) echo "unsupported architecture: $(uname -m)" >&2; return 1 ;; esac
  printf '%s-%s' "$os" "$arch"
}

SELF="${BASH_SOURCE[0]:-}"
expected="${LAZYAI_EXPECTED_SHA256:-}"
if [ -n "${LAZYAI_BINARY:-}" ]; then
  cp "$LAZYAI_BINARY" "$STAGE/lazyai"
elif [ -n "$SELF" ] && [ -x "$(dirname "$SELF")/dist/lazyai" ]; then
  cp "$(dirname "$SELF")/dist/lazyai" "$STAGE/lazyai"
else
  asset="lazyai-$(platform)"
  if [ "$VERSION" = latest ]; then
    url="https://github.com/jimmyliao/lazyaicli/releases/latest/download/$asset"
  else
    url="https://github.com/jimmyliao/lazyaicli/releases/download/$VERSION/$asset"
  fi
  echo "  downloading $url"
  curl -fsSL "$url" -o "$STAGE/lazyai"
  curl -fsSL "${url%/*}/SHA256SUMS" -o "$STAGE/SHA256SUMS"
  while read -r sum filename; do
    case "$filename" in ""|"$asset"|"*$asset") expected="$sum"; break ;; esac
  done <"$STAGE/SHA256SUMS"
  [ -n "$expected" ] || { echo "checksum for $asset not found" >&2; exit 1; }
fi

if [ -n "$expected" ]; then
  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$STAGE/lazyai")"; actual="${actual%% *}"
  elif command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$STAGE/lazyai")"; actual="${actual%% *}"
  else
    echo "checksum verification needs sha256sum or shasum" >&2
    exit 1
  fi
  [ "$actual" = "$expected" ] || { echo "checksum verification failed" >&2; exit 1; }
  echo "✓ SHA-256 verified"
fi

cp "$STAGE/lazyai" "$INSTALL_DIR/lazyai"
chmod +x "$INSTALL_DIR/lazyai"

for command_name in lazyai lazyaicli ccs ags cxs; do
  ln -sf "$INSTALL_DIR/lazyai" "$BIN_DIR/$command_name"
  echo "✓ linked $BIN_DIR/$command_name"
done

REPO_DIR=""
if [ -n "$SELF" ] && [ -f "$(dirname "$SELF")/lazyaicli.sh" ]; then
  REPO_DIR="$(cd "$(dirname "$SELF")" && pwd)"
else
  REPO_DIR="$INSTALL_DIR/shell"
  mkdir -p "$REPO_DIR"
  ref=main; [ "$VERSION" != latest ] && ref="$VERSION"
  for shell_file in lazyaicli.sh ccs.sh ags.sh cxs.sh; do
    curl -fsSL "https://raw.githubusercontent.com/jimmyliao/lazyaicli/$ref/$shell_file" -o "$REPO_DIR/$shell_file"
  done
fi

case "$(basename "${SHELL:-}")" in
  zsh) RC="$HOME/.zshrc" ;;
  bash) if [ "$(uname -s)" = Darwin ]; then RC="$HOME/.bash_profile"; else RC="$HOME/.bashrc"; fi ;;
  *) RC="" ;;
esac

if [ -n "$RC" ]; then
  mkdir -p "$(dirname "$RC")"
  touch "$RC"
  grep -qF "export PATH=\"$BIN_DIR:\$PATH\"" "$RC" 2>/dev/null || printf '\n# lazyai\nexport PATH="%s:$PATH"\n' "$BIN_DIR" >>"$RC"
  marker="source \"$REPO_DIR/lazyaicli.sh\""
  grep -qF "$marker" "$RC" 2>/dev/null || {
    printf '%s\n' "$marker" >>"$RC"
    printf 'source "%s/ccs.sh"\nsource "%s/ags.sh"\nsource "%s/cxs.sh"\n' "$REPO_DIR" "$REPO_DIR" "$REPO_DIR" >>"$RC"
  }
  echo "Done. Restart your shell or: source $RC"
else
  echo "Done. Add $BIN_DIR to PATH."
fi

echo ""
echo "Next steps:"
echo "  1. Restart Terminal (or source your shell rc file shown above)."
echo "  2. Check installed AI backends:  lazyai doctor"
echo "  3. Open your session picker:     lazyai"
echo ""
echo "No backend yet? Install AGY, Claude Code, or Codex, then run lazyai doctor again."
