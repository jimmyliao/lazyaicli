# ccs.sh — sourced shell function 版的 ccs
#
# 讓 `ccs` 還原 session 後，**當前 shell 留在該 session 的專案目錄**
# （獨立 script 的 cd 只在子行程內，退出 claude 後會彈回原目錄；
#  要 cd 持久到父 shell，唯一解就是 source 一個 function。）
#
# 安裝 / Install: run ./install.sh, or add to your ~/.zshrc / ~/.bashrc:
#     source /path/to/agent-cli-sessions/ccs.sh
#
# 行為：
#   ccs                 互動挑 → cd 專案目錄 + claude --resume（退出後留在該目錄）
#   ccs <關鍵字|id|N>   直接還原 → 同上
#   ccs -l / ls / list  只列出（不 cd、不還原）
#   其餘 flag           原樣轉給底層 ccs script

ccs() {
  # 純檢視 / help → 直接 pass-through，不動當前 shell
  case "${1:-}" in
    -l|--list|ls|list|-h|--help|--version)
      command ccs "$@"; return $? ;;
  esac

  # CCS_EMIT=1：底層只印 "cwd<TAB>id"（fzf UI 走 /dev/tty，不影響 stdout 擷取）
  local out
  out="$(CCS_EMIT=1 command ccs "$@")" || return $?
  [ -z "$out" ] && return 0          # 取消挑選 / 無相符

  local dir="${out%%$'\t'*}" id="${out#*$'\t'}"
  if [ -n "$dir" ] && [ -d "$dir" ]; then
    cd "$dir" || return 1
  elif [ -n "$dir" ]; then
    echo "⚠ 目錄不存在：$dir，留在原地還原" >&2
  fi
  command claude --resume "$id"
}
