# v0.1.0 release staging

Status: **RC1 ready for hands-on testing**

- Branch: `release/v0.1.0-rc1`
- Candidate version: `v0.1.0-rc1`
- Intended final tag after approval: `v0.1.0`
- Base code commit: `523d999`
- Tag: not created
- Remote push: not performed

## Automated verification

- `tests/cli_contract.sh` — passed
- `tests/backend_flows.sh` — passed
- `tests/backend_detection.sh` — passed
- `tests/edge_cases.sh` — passed
- `tests/install_binary.sh` — passed
- `go test ./...` — passed
- `go vet ./...` — passed
- Linux amd64 RC binary version — `lazyai v0.1.0-rc1`
- Clean-HOME install with SHA-256 verification — passed
- Clean-HOME `lazyai doctor` with zero backends — passed

## Candidate artifacts

Generated locally under ignored directory `dist/release/`:

```text
eb16fda21ce7c6964afd71a4dffc24dd589e411147dbaef52bc1c54220a19702  lazyai-darwin-amd64
3aba96bfe868a7ac4affe0c0e70d4cd5b868a400c7b0fe1018e4fe7d33716e1f  lazyai-darwin-arm64
409edf53ad366d8d1ccaf839fa1d34162ad10b43d4b3a29f7906a0aabe59e00f  lazyai-linux-amd64
4b45368b375dfe0956f1214f8e15c7960a850b91a9642c454b47445c287f9e58  lazyai-linux-arm64
```

These RC hashes are evidence for local testing only. The final `v0.1.0` workflow rebuilds artifacts with the final version string and generates new checksums.

## Hands-on test gate

- [ ] Fresh Terminal install flow reviewed
- [ ] `lazyai doctor` reviewed with zero installed backends
- [ ] AGY picker and resume tested by a real user
- [ ] Claude picker and resume tested by a real user
- [ ] Codex picker and resume tested by a real user
- [ ] macOS binary tested on Apple Silicon or Intel
- [ ] Final version approved

Only after this checklist is approved:

1. push `release/v0.1.0-rc1`;
2. merge the approved commit to `main`;
3. create annotated tag `v0.1.0` on that exact commit;
4. push the tag;
5. run or verify the Draft Release workflow;
6. test the public curl installer against the draft assets before publishing.
