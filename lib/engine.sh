# shellcheck shell=bash
# Shared lazyaicli shell engine.
# Adapters provide: gather(), resume(), usage(), no_sessions(), LAZY_COMMAND,
# LAZY_ITEM_EN/ZH, and LAZY_FZF_HEADER_EN/ZH.

case "${LAZYAICLI_LANG:-${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}}" in
  zh*) _LANG=zh ;;
  *)   _LANG=en ;;
esac
t() { if [ "$_LANG" = zh ]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }

run_python() {
  if command -v python3 >/dev/null 2>&1; then
    python3 "$@"
  elif command -v uv >/dev/null 2>&1; then
    uv run --no-project python "$@"
  else
    echo "$(t "✗ session parsing needs python3 or uv." "✗ 解析 session 需要 python3 或 uv。")" >&2
    return 127
  fi
}

version() {
  local rev="dev"
  command -v git >/dev/null 2>&1 && rev="$(git -C "$ROOT" describe --tags --always --dirty 2>/dev/null || printf dev)"
  printf 'lazyaicli %s (%s)\n' "$rev" "$LAZY_COMMAND"
}

row_at() {
  local rows="$1" requested="$2" number
  case "$requested" in ''|*[!0-9]*) return 1 ;; esac
  number="$(printf '%s' "$requested" | sed 's/^0*//')"
  [ -n "$number" ] || return 1
  printf '%s\n' "$rows" | awk -v n="$number" 'NR == n {print; exit}'
}

engine_main() {
  case "${1:-}" in
    -h|--help) usage; return 0 ;;
    --version) version; return 0 ;;
  esac

  local tsv
  tsv="$(gather | sort -t$'\t' -k3,3nr)"   # newest first
  if [ -z "$tsv" ]; then
    no_sessions
    return 1
  fi

  if [ "${1:-}" = "-l" ] || [ "${1:-}" = "--list" ] || [ "${1:-}" = "ls" ] || [ "${1:-}" = "list" ]; then
    printf '%s\n' "$tsv" | awk -F'\t' '{n[NR]=$6} END{for(i=NR;i>=1;i--) printf "%2d) %s\n", i, n[i]}'
    return 0
  fi

  if [ -n "${1:-}" ]; then
    local match
    if printf '%s' "$1" | grep -qE '^[0-9]+$'; then
      match="$(row_at "$tsv" "$1" || true)"
      if [ -z "$match" ]; then
        local total; total="$(printf '%s\n' "$tsv" | grep -c .)"
        echo "$(t "No ${LAZY_ITEM_EN} #${1} (${total} total)" "沒有第 ${1} 個${LAZY_ITEM_ZH}（共 ${total} 個）")" >&2
        return 1
      fi
    else
      match="$(printf '%s\n' "$tsv" | grep -iF -m1 -- "$1" || true)"
      if [ -z "$match" ]; then
        echo "$(t "No ${LAZY_ITEM_EN} matching \"${1}\"" "沒有符合「${1}」的${LAZY_ITEM_ZH}")" >&2
        return 1
      fi
    fi
    resume "$(printf '%s' "$match" | cut -f1)" "$(printf '%s' "$match" | cut -f2)"
    return $?
  fi

  if command -v fzf >/dev/null 2>&1; then
    local pick
    pick="$(printf '%s\n' "$tsv" \
      | fzf --delimiter='\t' --with-nth=6 --height=90% --reverse \
            --prompt='resume> ' --header="$(t "$LAZY_FZF_HEADER_EN" "$LAZY_FZF_HEADER_ZH")")" || return 0
    [ -z "$pick" ] && return 0
    resume "$(printf '%s' "$pick" | cut -f1)" "$(printf '%s' "$pick" | cut -f2)"
  else
    printf '%s\n' "$tsv" | awk -F'\t' '{printf "%2d) %s\n", NR, $6}'
    printf '%s' "$(t "Pick # (Enter to cancel): " "選擇 #（Enter 取消）：")"
    local n line
    read -r n
    [ -z "$n" ] && return 0
    line="$(row_at "$tsv" "$n" || true)"
    [ -z "$line" ] && { echo "$(t "invalid choice" "無效選擇")" >&2; return 1; }
    resume "$(printf '%s' "$line" | cut -f1)" "$(printf '%s' "$line" | cut -f2)"
  fi
}
