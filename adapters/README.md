# Adapters

`lazyaicli` separates a shared **engine** (list → pick → `cd` → resume) from per-tool **adapters**. Every terminal AI coding agent stores sessions differently; only three things change per tool.

The shared UX never changes — adding a new tool means writing one adapter, not a new tool.

## Adapter contract

An adapter sources [`../lib/engine.sh`](../lib/engine.sh) and must provide:

| # | Responsibility | Claude Code (today) |
|---|----------------|---------------------|
| 1 | **Enumerate sessions** — where they live | glob `~/.claude/projects/*/*.jsonl` |
| 2 | **Parse** each into a common record | read jsonl tail → fields below |
| 3 | **Resume command** | `cd <cwd> && claude --resume <id>` |

Shell contract:

- `gather()` emits six-column TSV: `id`, `cwd`, `mtime`, `name`, `preview`, `displayline`.
- `resume <id> <cwd>` performs dry-run/emit/direct resume for that backend.
- `usage()` and `no_sessions()` provide adapter-specific help and empty-state text.
- `LAZY_COMMAND`, `LAZY_ITEM_EN/ZH`, and `LAZY_FZF_HEADER_EN/ZH` supply display labels.

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
- ✅ **codex** — implemented in [`../bin/cxs`](../bin/cxs).
  `~/.codex/sessions/**/rollout-*-<UUID>.jsonl` (plain JSONL); id + cwd from the
  `session_meta` line; name = first real user prompt; resume `codex resume <id>`.

The shared engine now owns help/version, language selection, Python/uv fallback,
sorting, list/number/literal-keyword selection, fzf/menu interaction, and dispatch
to `resume()`. Adapter parsing and backend invocation stay tool-specific.

See [../ROADMAP.md](../ROADMAP.md).
