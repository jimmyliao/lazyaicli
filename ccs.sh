# ccs.sh — sourced shell-function wrapper for ccs
#
# Lets `ccs` keep your shell in the resumed session's project directory after
# you exit (a standalone script's cd only affects its child process; persisting
# cd to the parent shell requires a sourced function).
#
# Install: run ./install.sh, or add to your ~/.zshrc / ~/.bashrc:
#     source /path/to/lazyaicli/ccs.sh
#
# Behaviour:
#   ccs                interactive pick → cd into the dir + claude --resume (stays there on exit)
#   ccs <keyword|id|N> resume directly → same
#   ccs -l / ls / list list only (no cd, no resume)
#   other flags        passed through to the underlying ccs script

ccs() {
  # Listing / help → pass through, don't touch the current shell.
  case "${1:-}" in
    -l|--list|ls|list|-h|--help|--version)
      command ccs "$@"; return $? ;;
  esac

  # CCS_EMIT=1: the script just prints "cwd<TAB>id" (fzf UI uses /dev/tty, so stdout capture is clean).
  local out
  out="$(CCS_EMIT=1 command ccs "$@")" || return $?
  [ -z "$out" ] && return 0          # cancelled / no match

  local dir="${out%%$'\t'*}" id="${out#*$'\t'}"
  if [ -n "$dir" ] && [ -d "$dir" ]; then
    cd "$dir" || return 1
  elif [ -n "$dir" ]; then
    case "${LAZYAICLI_LANG:-${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}}" in
      zh*) echo "⚠ 目錄不存在：${dir}，留在原地還原" >&2 ;;
      *)   echo "⚠ directory not found: ${dir} — resuming in place" >&2 ;;
    esac
  fi
  command claude --resume "$id"
}
