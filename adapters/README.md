# Adapters

`agent-cli-sessions` separates a shared **engine** (list → pick → `cd` → resume) from per-tool **adapters**. Every terminal AI coding agent stores sessions differently; only three things change per tool.

The shared UX never changes — adding a new tool means writing one adapter, not a new tool.

## Adapter contract

An adapter must provide:

| # | Responsibility | Claude Code (today) |
|---|----------------|---------------------|
| 1 | **Enumerate sessions** — where they live | glob `~/.claude/projects/*/*.jsonl` |
| 2 | **Parse** each into a common record | read jsonl tail → fields below |
| 3 | **Resume command** | `cd <cwd> && claude --resume <id>` |

Common session record (what the engine consumes):

```
{
  id:          string   # stable session id (used for resume)
  title:       string   # custom-title → ai-title → "(untitled)"
  last_prompt: string   # last user message, for disambiguation
  cwd:         string   # working dir to cd into on resume
  mtime:       number   # last-modified epoch, for sorting
}
```

## Status

- ✅ **claude** — implemented in [`../bin/ccs`](../bin/ccs).
  `~/.claude/projects/*/*.jsonl`; resume `claude --resume <id>` from the session's
  launch dir (first cwd).
- ✅ **agy (Antigravity)** — implemented in [`../bin/ags`](../bin/ags).
  `~/.gemini/antigravity-cli/conversations/<UUID>.db` (SQLite) / `.pb` (legacy);
  id = filename UUID; cwd = invert `cache/last_conversations.json`; resume
  `agy --conversation <id>`. Title/last_prompt: heuristic text from the `.db`
  `steps.step_payload` blob (protobuf, no schema) — `.pb` previews not yet decoded.
- ⏳ **codex** — planned. `~/.codex/sessions/` + sqlite.

> **Refactor note (v0.2):** `bin/ccs` and `bin/ags` currently duplicate the shared
> engine (gather → fzf → list/number/keyword → cd → resume). With two real adapters
> now in place, the next step is to extract that engine here and make `bin/ccs` /
> `bin/ags` thin entrypoints. The record shape above is the seam.

See [../ROADMAP.md](../ROADMAP.md).
