# Roadmap

## v0.1 — Claude Code (current)
- [x] list sessions (title / last prompt / cwd / age), newest at bottom
- [x] interactive `fzf` picker, numbered-menu fallback
- [x] resume by list number (`ccs <N>`, `1` = newest) / keyword / id prefix
- [x] `cd` into the session's directory on resume (`ccs.sh` shell function = stays there after exit)
- [x] `install.sh` with shell/rc detection (zsh / bash on macOS & Linux/WSL)

## v0.2 — Adapter seam
- [ ] extract shared engine (gather → fzf → cd → resume) from `bin/ccs`
- [ ] formalize the adapter contract (see [adapters/README.md](./adapters/README.md))
- [ ] `bin/ccs` becomes the thin `claude` entrypoint

## v0.3 — Antigravity (`agy`)  ✅ shipped
- [x] reverse-engineered storage: `~/.gemini/antigravity-cli/conversations/<UUID>.db` (SQLite) / `.pb` (legacy protobuf)
- [x] map to the common record: id = filename UUID, cwd = invert `cache/last_conversations.json`, mtime = file mtime
- [x] resume via `agy --conversation <id>` (verified loads context)
- [x] shipped as command `ags` + `ags.sh` (cd-persist)
- [ ] better title/last_prompt: decode protobuf in `steps.step_payload` (today only `.db` shows a heuristic text preview; `.pb` lists by dir+time)
- [ ] recover cwd for conversations not in `last_conversations.json`

## v0.4 — Codex  ✅ shipped
- [x] Codex adapter: `~/.codex/sessions/**/rollout-*-<UUID>.jsonl` (plain JSONL)
- [x] id + cwd straight from `session_meta`; name = first real user prompt
- [x] resume via `codex resume <id>`; shipped as command `cxs` + `cxs.sh`

## v0.5 — Extract shared engine (refactor)
- [ ] `bin/ccs` / `bin/ags` / `bin/cxs` duplicate the engine — extract to `lib/`
- [ ] each tool becomes gather() + resume() only (see [adapters/README.md](./adapters/README.md))
- [ ] auto-detect installed tools; a top-level dispatcher across all of them

## Nice-to-have
- [ ] i18n of user-facing strings (currently mixed zh-TW / English)
- [ ] `fish` shell function (`ccs.fish`) for cd-persist
- [ ] optional preview pane (session summary) in the fzf picker
