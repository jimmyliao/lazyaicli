# Contributing

Build and run all tests:

```bash
CGO_ENABLED=0 go build -o dist/lazyai ./cmd/lazyai
tests/cli_contract.sh
tests/backend_flows.sh
tests/backend_detection.sh
tests/edge_cases.sh
tests/install_binary.sh
```

Requirements for changes:

- Add or update the failing contract test before implementation.
- Keep `lazyai --help` and README's command reference synchronized.
- Do not add user runtime dependencies.
- Cover AGY, Claude, and Codex when shared behavior changes.
- Run `gofmt` and all tests before proposing a commit.
