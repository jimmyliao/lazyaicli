# shellcheck shell=bash
# Source this file to keep the resumed session directory after the CLI exits.

_lazyai_resume() {
  local selected backend cwd id
  case "${1:-}" in
    -h|--help|-V|--version|help|default|list|doctor) command lazyai "$@"; return $? ;;
  esac
  case "${2:-}" in
    -h|--help|-V|--version|-l|--list|list|ls) command lazyai "$@"; return $? ;;
  esac
  selected="$(LAZYAI_EMIT=1 command lazyai "$@")" || return $?
  [ -n "$selected" ] || return 0
  IFS=$'\t' read -r backend cwd id <<<"$selected"
  cd "$cwd" || return $?
  case "$backend" in
    agy) command agy --conversation "$id" ;;
    claude) command claude --resume "$id" ;;
    codex) command codex resume "$id" ;;
    *) printf 'lazyai: invalid backend emitted: %s\n' "$backend" >&2; return 1 ;;
  esac
}

lazyai() { _lazyai_resume "$@"; }
lazyaicli() { _lazyai_resume "$@"; }
