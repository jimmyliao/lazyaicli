# ops.sh — sourced shell-function wrapper for ops (Oh My Pi session browser)
#
# Lets `ops` keep your shell in the resumed session's directory after you exit
# (persisting cd to the parent shell requires a sourced function).
#
# Install: run ./install.sh, or add to your ~/.zshrc / ~/.bashrc:
#     source /path/to/lazyaicli/ops.sh

ops() {
  case "${1:-}" in
    -l|--list|ls|list|-h|--help|--version)
      command ops "$@"; return $? ;;
  esac

  local out
  out="$(OPS_EMIT=1 command ops "$@")" || return $?
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
  command omp --resume "$id"
}
