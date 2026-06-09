# lazyaicli

> Browse and resume your AI coding CLI sessions from the terminal — pick one, jump straight back into it (and back into its directory).
>
> 在終端機列出、跳回你的 AI coding CLI session —— 挑一個，直接還原（連工作目錄一起回去）。

**繁體中文 | English** · MIT License

**lazyaicli** is the project; it ships three commands, one per tool, sharing one engine. Each name is just `<tool> Sessions`:

- **`ccs`** — **C**laude **C**ode **S**essions (`~/.claude/projects`)
- **`ags`** — **A**nti**g**ravity **S**essions · `agy` (`~/.gemini/antigravity-cli/conversations`)
- **`cxs`** — Code**x** **S**essions (`~/.codex/sessions`)

Same UX everywhere — list → pick → `cd` → resume. Adding a tool is one adapter.

---

## Why / 為什麼

Terminal AI coding agents write a session per project, but resuming the *right* one means remembering a long id and `cd`-ing to the right folder. On an ephemeral / preemptible cloud box, a reboot wipes your terminal and you restore them by hand.

終端機 AI coding agent 每個專案存一個 session，但要還原「對的那個」得記一長串 id、再 `cd` 回對的目錄。在會被回收的雲端機（Spot/preemptible）上，重開機後還得手動一個個救回來。

`ccs` lists every session with its **title / last prompt / directory / age**, lets you pick with `fzf`, then `cd`s into that session's directory and resumes it.

---

## Demo

```text
$ ccs -l
 3)  2d ago  [Fix login redirect bug]   ~/projects/web-app   ↳ the session cookie isn't set on the callback route
 2)  5h ago  [Refactor payment module]  ~/projects/api       ↳ extract the stripe client into its own module
 1)  3m ago  [Write auth unit tests]    ~/projects/web-app   ↳ add coverage for the middleware

$ ccs            # interactive fzf picker → cd + resume
$ ccs auth       # resume the session matching "auth"
```

> Newest is listed at the **bottom** (closest to your prompt); `1)` is always the most recent.

---

## Requirements / 需求

- **At least one supported CLI** — Claude Code, Antigravity (`agy`), and/or Codex. Each is optional; you only need the ones you actually use. Listing only reads their session files; resuming needs that CLI on `PATH`.
- **python3** (parsing) — required
- **bash** — the engine runs under bash
- **fzf** — optional, enables the interactive picker (falls back to a numbered menu)
- Works on **macOS (zsh)** and **Linux / WSL (bash)**. Windows: use WSL.

---

## Install / 安裝

**One-liner (recommended):**

```bash
curl -fsSL ccs.jimmyliao.net/install | bash
```

<sub>Or straight from GitHub: `curl -fsSL https://raw.githubusercontent.com/jimmyliao/lazyaicli/main/install.sh | bash`</sub>

**Manual:**

```bash
git clone https://github.com/jimmyliao/lazyaicli.git
cd lazyaicli
./install.sh
```

Either way, `install.sh` will:
1. (one-liner mode) clone into `~/.local/share/lazyaicli`
2. symlink `ccs`, `ags`, `cxs` into `~/.local/bin`
3. detect your shell and source `ccs.sh` / `ags.sh` / `cxs.sh` from the right rc file (`~/.zshrc` / `~/.bashrc` / `~/.bash_profile`)
4. check `python3` (required) and `fzf` (recommended); note which of `claude` / `agy` / `codex` are present

Then restart your shell (or `source` your rc file). Update later with `git -C ~/.local/share/lazyaicli pull` (or just re-run the one-liner).

> The `ccs.sh` shell function is what lets your shell **stay in the resumed session's directory after you exit** — a plain script can't change its parent shell's working directory. Sourcing is optional; `ccs` works as a standalone command without it (minus the cd-persist).

---

## Usage / 用法

| Command | What it does |
|---------|--------------|
| `ccs` | interactive picker (fzf) → `cd` into session dir + resume |
| `ccs -l` / `ccs ls` | list only (newest at bottom), no resume |
| `ccs <N>` | resume by list number from `ccs -l` (`1` = newest) |
| `ccs <keyword>` | resume the newest session whose title / last prompt matches |
| `ccs <id-prefix>` | resume by session id prefix |

Environment:
- `CLAUDE_PROJECTS` — override the projects dir (default `~/.claude/projects`)
- `CCS_DRYRUN=1` — print the resume command instead of executing (testing)

### `ags` — Antigravity (`agy`) sessions

Same interface, for Antigravity CLI conversations:

| Command | What it does |
|---------|--------------|
| `ags` | interactive picker → `cd` + `agy --conversation <id>` |
| `ags -l` | list only (newest at bottom) |
| `ags <N>` / `<keyword>` / `<id>` | resume by number / preview match / id |

Conversations live in `~/.gemini/antigravity-cli/conversations/<UUID>.db` (SQLite, current) or `.pb` (legacy protobuf). Directory comes from `cache/last_conversations.json`. Names are the first prompt for `.db` conversations; legacy `.pb` files show `[legacy]` + directory + time. Env: `AGY_HOME`, `AGS_DRYRUN=1`.

### `cxs` — Codex sessions

| Command | What it does |
|---------|--------------|
| `cxs` | interactive picker → `cd` + `codex resume <id>` |
| `cxs -l` | list only (newest at bottom) |
| `cxs <N>` / `<keyword>` / `<id>` | resume by number / name match / id |

Sessions live in `~/.codex/sessions/YYYY/MM/DD/rollout-*-<UUID>.jsonl` (plain JSONL). Both id and `cwd` come straight from the `session_meta` line; the name is the first real user prompt. Env: `CODEX_HOME`, `CXS_DRYRUN=1`.

---

## How it works / 原理

One engine, three thin adapters. The engine: scan a tool's session store → one row per session (`id` / name / `cwd` / mtime) → sort newest-last → pick (`fzf`, or a number/keyword) → `cd` into the session's directory → run that tool's resume command. **Listing is read-only** over files the CLI already writes, so there's no save step; only *resume* needs the CLI on `PATH`.

What differs per tool:

| Tool | Session store | Name from | `cd` target | Resume |
|------|---------------|-----------|-------------|--------|
| `ccs` | `~/.claude/projects/*/*.jsonl` | `custom-title` → `ai-title` → last prompt | **launch dir** = first `cwd` in the file | `claude --resume <id>` |
| `ags` | `~/.gemini/antigravity-cli/conversations/<UUID>.db` (sqlite) / `.pb` (legacy) | first prompt from `steps` (`.db` only; `.pb` → `[legacy]`) | invert `cache/last_conversations.json` | `agy --conversation <id>` |
| `cxs` | `~/.codex/sessions/**/rollout-*-<UUID>.jsonl` | first real user prompt | `cwd` from the `session_meta` line | `codex resume <id>` |

> **Launch dir** matters for `ccs`: `claude --resume` resolves a session by *current dir → project dir*, so a session that `cd`-ed into a subdir mid-way would fail to resume from that subdir. `ccs` reads the file **head** for the original launch `cwd` (and the **tail** for title / last prompt) and `cd`s there.

---

## Roadmap / 藍圖

Today **Claude Code, Antigravity (`agy`), and Codex** all work — `ccs` / `ags` / `cxs`. Next up:

- [ ] extract the shared engine — `bin/ccs` / `bin/ags` / `bin/cxs` still duplicate it (each should be just gather + resume)
- [ ] decode legacy `agy` `.pb` conversations for names (they list as `[legacy]` today)
- [ ] more backends (OpenCode, Cursor, Copilot CLI, Gemini CLI, …)
- [ ] auto-detect installed tools + a top-level dispatcher

Full detail in [ROADMAP.md](./ROADMAP.md). Contributions welcome — a new tool is **one adapter**: see [adapters/README.md](./adapters/README.md) and [CONTRIBUTING.md](./CONTRIBUTING.md).

---

## License

[MIT](./LICENSE) © 2026 Jimmy Liao
