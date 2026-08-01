# Contributing

Thanks for your interest! `lazyaicli` is a small, focused tool.

## Adding support for another CLI agent

The fastest way to contribute is a new **adapter** (e.g. Antigravity `agy`, Codex).
Read [adapters/README.md](./adapters/README.md) — you only need to provide:

1. where that tool stores sessions,
2. how to parse one into the common record (`id` / `title` / `last_prompt` / `cwd` / `mtime`),
3. the resume command.

The shared UX (list → pick → `cd` → resume) is reused as-is.

## Ground rules

- Keep the engine dependency-light: `bash` + (`python3` or `uv`) + optional `fzf`.
- Run `tests/smoke.sh` before submitting changes; it exercises all three adapters with isolated fixtures.
- Pull requests run the same smoke suite on Ubuntu and macOS, plus ShellCheck on Ubuntu, in GitHub Actions.
- Read-only over session data — never mutate a tool's session files.
- Test with `CCS_DRYRUN=1` (prints the resume command instead of executing).
- Cross-shell: behavior must hold on **zsh** (macOS) and **bash** (Linux/WSL).

## Dev / test

```bash
CCS_DRYRUN=1 ./bin/ccs -l          # list, no resume
CCS_DRYRUN=1 ./bin/ccs <keyword>   # show what would be resumed
```

Open an issue first for anything larger than a bug fix, so we can align on the adapter interface.
