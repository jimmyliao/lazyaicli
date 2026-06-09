# cxs.sh — sourced shell function 版的 cxs（Codex CLI session browser）
#
# 讓 `cxs` 還原 codex session 後，**當前 shell 留在該 session 的目錄**。
#
# 安裝 / Install: run ./install.sh, or add to your ~/.zshrc / ~/.bashrc:
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
    echo "⚠ 目錄不存在：$dir，留在原地還原" >&2
  fi
  command codex resume "$id"
}
