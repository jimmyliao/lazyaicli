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

- ✅ **claude** — currently implemented **inline in `../bin/ccs`**. When the second
  adapter lands, the shared engine (gather/fzf/list/cd) will be extracted here and
  `bin/ccs` becomes a thin `claude` entrypoint. The record shape above is already
  the seam, so this is an additive refactor, not a rewrite.
- ⏳ **agy (Antigravity)** — planned. Sessions under `~/.antigravity/` (VS Code
  workspace storage; storage format to be confirmed). Resume via the `agy` CLI.
- ⏳ **codex** — planned. `~/.codex/sessions/` + sqlite.

See [../ROADMAP.md](../ROADMAP.md).
