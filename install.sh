#!/usr/bin/env bash
# agent-cli-sessions installer
#   - symlinks bin/ccs into ~/.local/bin
#   - sources ccs.sh from the right shell rc file (cd-persist after resume)
#   - checks deps: python3 (required), fzf (recommended)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
BIN_DIR="${CCS_BIN_DIR:-$HOME/.local/bin}"

echo "agent-cli-sessions installer"
echo "  repo: $REPO_DIR"

# --- deps -------------------------------------------------------------------
if ! command -v python3 >/dev/null 2>&1; then
  echo "✗ python3 is required (sessions are parsed with python3). Aborting." >&2
  exit 1
fi
echo "✓ python3: $(python3 --version 2>&1)"
if command -v fzf >/dev/null 2>&1; then
  echo "✓ fzf: $(fzf --version 2>&1 | head -1)"
else
  echo "⚠ fzf not found — interactive picker falls back to a numbered menu."
  echo "    install: brew install fzf   |   apt install fzf"
fi

# --- optional: Antigravity CLI (agy) ---------------------------------------
if command -v agy >/dev/null 2>&1; then
  echo "✓ agy: $(agy --version 2>&1 | head -1) — installing ags (Antigravity sessions) too"
else
  echo "ℹ agy (Antigravity CLI) not found — ags is installed but only works once agy is present."
fi

# --- symlink engines onto PATH ---------------------------------------------
mkdir -p "$BIN_DIR"
ln -sf "$REPO_DIR/bin/ccs" "$BIN_DIR/ccs"
echo "✓ linked $BIN_DIR/ccs -> $REPO_DIR/bin/ccs   (Claude Code sessions)"
ln -sf "$REPO_DIR/bin/ags" "$BIN_DIR/ags"
echo "✓ linked $BIN_DIR/ags -> $REPO_DIR/bin/ags   (Antigravity agy sessions)"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "⚠ $BIN_DIR is not on PATH — add it, e.g.  export PATH=\"$BIN_DIR:\$PATH\"" ;;
esac

# --- source the shell function (cd-persist) --------------------------------
detect_rc() {
  case "$(basename "${SHELL:-}")" in
    zsh)  echo "$HOME/.zshrc" ;;
    bash) if [ "$(uname)" = "Darwin" ]; then echo "$HOME/.bash_profile"; else echo "$HOME/.bashrc"; fi ;;
    *)    echo "" ;;
  esac
}
RC="$(detect_rc)"
if [ -n "$RC" ]; then
  if grep -qF "$REPO_DIR/ccs.sh" "$RC" 2>/dev/null; then
    echo "✓ ccs.sh already sourced in $RC"
  else
    printf '\n# agent-cli-sessions — stay in the resumed session dir after exit\nsource "%s/ccs.sh"\n' "$REPO_DIR" >> "$RC"
    echo "✓ added ccs.sh source line to $RC"
  fi
  if grep -qF "$REPO_DIR/ags.sh" "$RC" 2>/dev/null; then
    echo "✓ ags.sh already sourced in $RC"
  else
    printf 'source "%s/ags.sh"\n' "$REPO_DIR" >> "$RC"
    echo "✓ added ags.sh source line to $RC"
  fi
  echo ""
  echo "Done. Restart your shell or:  source $RC"
else
  echo "⚠ Unknown shell ($SHELL). Add these lines to your shell rc manually:"
  echo "    source \"$REPO_DIR/ccs.sh\""
  echo "    source \"$REPO_DIR/ags.sh\""
fi
