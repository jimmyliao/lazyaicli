# lazyai {{VERSION}}

Review draft — not yet published.

## Highlights

- One `lazyai` wrapper for AGY, Claude Code, and Codex.
- AGY is the default backend; users can persist a different default.
- Existing `ags`, `ccs`, and `cxs` commands remain available.
- Self-contained Linux and macOS binaries for amd64 and arm64.
- No Python, uv, jq, fzf, or other user runtime libraries.
- Shared list, search, session selection, cwd, and resume behavior.

## Reviewer checklist

- [ ] Confirm `lazyai --help` wording and command names.
- [ ] Confirm AGY should remain the fresh-install default.
- [ ] Review the three backend demo captures.
- [ ] Review installer behavior and compatibility alias `lazyaicli`.
- [ ] Approve version number and publish the draft release.

## Verification

- CLI contract tests
- AGY, Claude, and Codex fake-session flows
- Shell cwd persistence
- Binary installer test
- Go test, vet, and formatting
- Real AGY SQLite store read-only listing
