# Roadmap

## v0.1 — Claude Code (current)
- [x] list sessions (title / last prompt / cwd / age), newest at bottom
- [x] interactive `fzf` picker, numbered-menu fallback
- [x] resume by keyword / id prefix
- [x] `cd` into the session's directory on resume (`ccs.sh` shell function = stays there after exit)
- [x] `install.sh` with shell/rc detection (zsh / bash on macOS & Linux/WSL)

## v0.2 — Adapter seam
- [ ] extract shared engine (gather → fzf → cd → resume) from `bin/ccs`
- [ ] formalize the adapter contract (see [adapters/README.md](./adapters/README.md))
- [ ] `bin/ccs` becomes the thin `claude` entrypoint

## v0.3 — Antigravity (`agy`)  ← next concrete target
- [ ] reverse-engineer session storage under `~/.antigravity/` (VS Code workspace storage; likely sqlite `state.vscdb` / per-workspace json)
- [ ] map to the common session record (id / title / last_prompt / cwd / mtime)
- [ ] resume via the `agy` CLI
- [ ] ship as command `ags` (Antigravity Coding Sessions)

## v0.4 — Codex & beyond
- [ ] Codex adapter (`~/.codex/sessions/` + sqlite) → command `cxs`
- [ ] auto-detect installed tools; `ccs` can dispatch across all of them

## Nice-to-have
- [ ] i18n of user-facing strings (currently mixed zh-TW / English)
- [ ] `fish` shell function (`ccs.fish`) for cd-persist
- [ ] optional preview pane (session summary) in the fzf picker
