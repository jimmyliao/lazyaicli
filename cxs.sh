# shellcheck shell=bash
[ "$(type -t _lazyai_resume 2>/dev/null)" = function ] || source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lazyaicli.sh"
cxs() { _lazyai_resume codex "$@"; }
