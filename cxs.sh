# shellcheck shell=bash
# cxs.sh — sourced shell-function wrapper for cxs (Codex CLI session browser)
#
# Lets `cxs` keep your shell in the resumed session's directory after you exit
# (persisting cd to the parent shell requires a sourced function).
#
# Install: run ./install.sh, or add to your ~/.zshrc / ~/.bashrc:
#     source /path/to/lazyaicli/cxs.sh

cxs() {
  case "${1:-}" in
    -l|--list|ls|list|-h|--help|--version)
      command cxs "$@"; return $? ;;
  esac

  local out
  out="$(CXS_EMIT=1 command cxs "$@")" || return $?
  [ -z "$out" ] && return 0

  local dir="${out%%$'\t'*}" id="${out#*$'\t'}"
  if [ -n "$dir" ] && [ -d "$dir" ]; then
    cd "$dir" || return 1
  elif [ -n "$dir" ]; then
    case "${LAZYAICLI_LANG:-${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}}" in
      zh*) echo "⚠ 目錄不存在：${dir}，留在原地還原" >&2 ;;
      *)   echo "⚠ directory not found: ${dir} — resuming in place" >&2 ;;
    esac
  fi
  command codex resume "$id"
}
