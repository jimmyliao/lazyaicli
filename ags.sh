# ags.sh — sourced shell function 版的 ags（Antigravity CLI session browser）
#
# 讓 `ags` 還原 agy 對話後，**當前 shell 留在該對話的目錄**
# （獨立 script 的 cd 只在子行程內；要 cd 持久到父 shell，唯一解是 source 一個 function。）
#
# 安裝 / Install: run ./install.sh, or add to your ~/.zshrc / ~/.bashrc:
#     source /path/to/lazyaicli/ags.sh
#
# 行為：
#   ags                 互動挑 → cd 目錄 + agy --conversation（退出後留在該目錄）
#   ags <關鍵字|id|N>   直接還原 → 同上
#   ags -l / ls / list  只列出（不 cd、不還原）
#   其餘 flag           原樣轉給底層 ags script

ags() {
  case "${1:-}" in
    -l|--list|ls|list|-h|--help|--version)
      command ags "$@"; return $? ;;
  esac

  local out
  out="$(AGS_EMIT=1 command ags "$@")" || return $?
  [ -z "$out" ] && return 0

  local dir="${out%%$'\t'*}" id="${out#*$'\t'}"
  if [ -n "$dir" ] && [ -d "$dir" ]; then
    cd "$dir" || return 1
  elif [ -n "$dir" ]; then
    echo "⚠ 目錄不存在：$dir，留在原地還原" >&2
  fi
  command agy --conversation "$id"
}
