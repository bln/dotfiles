# Testing

## Quick start

```bash
mise run test          # lint + all suites
mise run test:static   # static analysis only
mise run test:unit     # unit tests only
mise run test:contract # contract tests only
```

Or call the runner directly:

```bash
bash tests/run.sh             # all suites
bash tests/run.sh static      # one suite
```

## Suites

| Suite | Directory | What it checks | Requires host state? |
|---|---|---|---|
| **static** | `tests/static/` | Config formats, reference hygiene, secret handling | No |
| **unit** | `tests/unit/` | Individual task/script behavior in isolation | No |
| **contract** | `tests/contract/` | Repo shape, naming conventions, package policy | No |
| **integration** | `tests/integration/` | End-to-end flows against installed machine state | Yes |

Static, unit, and contract suites run in CI on every push and pull request.
Integration tests are for local validation only.

## Writing tests

### Conventions

- Every test file is named `test-*.sh`.
- Every test file starts with `#!/usr/bin/env bash` and `set -euo pipefail`.
- Source the shared test library: `source "${BASH_SOURCE[0]%/*}/../testlib.sh"`.
- Use `ok "description"` for passing checks and `bad "description"` for failures.
- Tests must be host-independent (no network, no installed tools required) unless
  placed in `tests/integration/`.

### Test library

`tests/testlib.sh` provides:

- `ok <msg>` - record a passing assertion.
- `bad <msg>` - record a failing assertion and set nonzero exit.
- `EXIT` trap that prints the summary and exits with the correct code.

### Adding a new test

1. Create `tests/<suite>/test-<name>.sh`.
2. Source `testlib.sh`, write your checks using `ok`/`bad`.
3. Run `mise run test:<suite>` to verify.
4. The runner auto-discovers all `test-*.sh` files in each suite directory.

### Contract tests

Contract tests enforce structural invariants about the repository itself:

- **test-package-policy.sh** - No direct `brew install/uninstall/bundle` in
  scripts, tasks, or workflows. No hard-coded `/opt/homebrew` in portable code.
- **test-repo-shape.sh** - Required documentation files exist, every shipped
  script has at least one test, test files follow the `test-*.sh` naming
  convention, public mise tasks are declared.

These run fast and catch drift before it reaches a host.
