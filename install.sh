#!/usr/bin/env bash
# lazyaicli installer
#   - symlinks bin/ccs into ~/.local/bin
#   - sources ccs.sh from the right shell rc file (cd-persist after resume)
#   - checks deps: python3 or uv (required), fzf (recommended)
set -euo pipefail

REPO_URL="${ACS_REPO_URL:-https://github.com/jimmyliao/lazyaicli.git}"
INSTALL_DIR="${ACS_DIR:-$HOME/.local/share/lazyaicli}"
BIN_DIR="${CCS_BIN_DIR:-$HOME/.local/bin}"

echo "lazyaicli installer"

# Two modes:
#  1) run from inside a clone (git clone … && ./install.sh)  -> use that checkout
#  2) bootstrap (curl -fsSL …/install.sh | bash)             -> clone/update INSTALL_DIR
SELF="${BASH_SOURCE[0]:-}"
if [ -n "$SELF" ] && [ -f "$(dirname "$SELF")/bin/ccs" ]; then
  REPO_DIR="$(cd "$(dirname "$SELF")" && pwd)"
  echo "  using checkout: $REPO_DIR"
else
  command -v git >/dev/null 2>&1 || { echo "✗ git is required to bootstrap. Aborting." >&2; exit 1; }
  if [ -d "$INSTALL_DIR/.git" ]; then
    echo "  updating $INSTALL_DIR"
    git -C "$INSTALL_DIR" pull --ff-only --quiet || echo "  (pull skipped)"
  else
    echo "  cloning $REPO_URL -> $INSTALL_DIR"
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone --depth 1 --quiet "$REPO_URL" "$INSTALL_DIR"
  fi
  REPO_DIR="$INSTALL_DIR"
fi

# --- deps -------------------------------------------------------------------
if command -v python3 >/dev/null 2>&1; then
  echo "✓ python3: $(python3 --version 2>&1)"
elif command -v uv >/dev/null 2>&1; then
  echo "✓ uv: $(uv --version 2>&1) (managed Python will parse sessions)"
else
  echo "✗ python3 or uv is required to parse sessions. Aborting." >&2
  exit 1
fi
if command -v fzf >/dev/null 2>&1; then
  echo "✓ fzf: $(fzf --version 2>&1 | head -1)"
else
  echo "⚠ fzf not found — interactive picker falls back to a numbered menu."
  echo "    install: brew install fzf   |   apt install fzf"
fi

# --- which backends are present? (all 3 commands install either way) -------
command -v claude >/dev/null 2>&1 && echo "✓ claude found — ccs (Claude Code sessions) ready" || echo "ℹ claude not found — ccs installed, works once Claude Code is present."
command -v agy    >/dev/null 2>&1 && echo "✓ agy found — ags (Antigravity sessions) ready"     || echo "ℹ agy not found — ags installed, works once Antigravity CLI is present."
command -v codex  >/dev/null 2>&1 && echo "✓ codex found — cxs (Codex sessions) ready"          || echo "ℹ codex not found — cxs installed, works once Codex CLI is present."

# --- symlink engines onto PATH ---------------------------------------------
mkdir -p "$BIN_DIR"
ln -sf "$REPO_DIR/bin/ccs" "$BIN_DIR/ccs"
echo "✓ linked $BIN_DIR/ccs -> $REPO_DIR/bin/ccs   (Claude Code sessions)"
ln -sf "$REPO_DIR/bin/ags" "$BIN_DIR/ags"
echo "✓ linked $BIN_DIR/ags -> $REPO_DIR/bin/ags   (Antigravity agy sessions)"
ln -sf "$REPO_DIR/bin/cxs" "$BIN_DIR/cxs"
echo "✓ linked $BIN_DIR/cxs -> $REPO_DIR/bin/cxs   (Codex sessions)"

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
  touch "$RC"
  if case ":$PATH:" in *":$BIN_DIR:"*) true;; *) false;; esac; then
    :
  elif grep -qF "export PATH=\"$BIN_DIR:\$PATH\"" "$RC" 2>/dev/null; then
    echo "✓ $BIN_DIR PATH already configured in $RC"
  else
    printf '\n# lazyaicli commands\nexport PATH="%s:$PATH"\n' "$BIN_DIR" >> "$RC"
    echo "✓ added $BIN_DIR to PATH in $RC"
  fi
  if grep -qF "$REPO_DIR/ccs.sh" "$RC" 2>/dev/null; then
    echo "✓ ccs.sh already sourced in $RC"
  else
    printf '\n# lazyaicli — stay in the resumed session dir after exit\nsource "%s/ccs.sh"\n' "$REPO_DIR" >> "$RC"
    echo "✓ added ccs.sh source line to $RC"
  fi
  for fn in ags cxs; do
    if grep -qF "$REPO_DIR/$fn.sh" "$RC" 2>/dev/null; then
      echo "✓ $fn.sh already sourced in $RC"
    else
      printf 'source "%s/%s.sh"\n' "$REPO_DIR" "$fn" >> "$RC"
      echo "✓ added $fn.sh source line to $RC"
    fi
  done
  echo ""
  echo "Done. Restart your shell or:  source $RC"
else
  echo "⚠ Unknown shell ($SHELL). Add these lines to your shell rc manually:"
  echo "    source \"$REPO_DIR/ccs.sh\""
  echo "    source \"$REPO_DIR/ags.sh\""
  echo "    source \"$REPO_DIR/cxs.sh\""
fi
