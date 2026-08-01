# shellcheck shell=bash
# lazyaicli.sh — sourced wrapper that preserves adapter cd behavior.

lazyaicli() {
  case "${1:-}" in
    -h|--help|--version)
      command lazyaicli "$@"; return $? ;;
  esac

  local tool
  case "${1:-}" in
    ccs|ags|cxs) tool="$1"; shift ;;
    *) tool="$(LAZYAICLI_EMIT_TOOL=1 command lazyaicli)" || return $? ;;
  esac
  "$tool" "$@"
}
