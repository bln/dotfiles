# Contributing

## Scope

This repository is a macOS dotfiles configuration managed through mise. Changes
must preserve a mise-first, declarative, idempotent workflow and must not assume
ownership of unrelated user state.

## Where changes belong

| What | Where |
|---|---|
| Versioned portable tool | `[tools]` in `home/.config/mise/config.toml` (workstation-wide) or `mise.toml` (development-only) |
| Native package or macOS application | `[bootstrap.packages]` in the global config |
| Stateful setup (links, generated config) | An executable mise task under `tasks/` |
| Repository-owned configuration | `home/` using its `$HOME`-relative path |
| Agent instructions and skills | explicit `[dotfiles]` entries in copy mode |
| Machine identity or secrets | Generated ignored files, never tracked values |

See `docs/ARCHITECTURE.md` (two-file boundary and package policy).

## Requirements

- Keep scripts compatible with Bash 3.2 unless explicitly documented otherwise.
- Use `set -euo pipefail` in Bash scripts.
- Quote expansions and support paths containing spaces.
- Make setup and reconciliation tasks idempotent.
- Give destructive commands a dry-run mode.
- Do not add direct native package-manager commands (`brew install`, `brew bundle`,
  etc.) in scripts, tasks, tests, or CI workflows. Use mise package resource
  declarations (`brew:`, `brew-cask:`) in the configuration instead.
- Do not hard-code architecture-specific paths like `/opt/homebrew`.

## Commit style

Use Conventional Commits: `type(scope): description`

Types: `feat`, `fix`, `docs`, `test`, `ci`, `refactor`, `chore`.
Scopes: `zsh`, `git`, `nvim`, `ghostty`, `vscode`, `mise`, `ci`, `teardown`, etc.

## Tests

Add or update tests for every behavior change. Run from the repo root (or use
`dot run test` from anywhere):

```sh
mise run test          # host-independent repository tests (what CI runs)
mise run verify        # additionally runs host-only checks + machine state (macOS)
```

### Suites

| Suite | Directory | Checks | Needs host state? |
|---|---|---|---|
| **static** | `tests/static/` | Config parse/shape, version consistency, template + secret hygiene, lint | No |
| **unit** | `tests/unit/` | Individual task/script behavior via env-var seams and fake-binary shims | No |
| **integration** | `tests/integration/` | Real mise plan reproducibility; sandboxed zsh startup under a pty | Skips cleanly if mise/zsh absent |
| **verify** | `tests/verify/` | Tools resolve on PATH, plugins loaded, install re-run idempotent | Yes (macOS host, not CI) |

static, unit, and integration run in CI on every push and PR (`mise run test`);
integration tests skip cleanly when mise or zsh is unavailable. The verify suite
is host-coupled behavioral validation wired into `mise run verify`, never CI.

### Conventions

- Name test files `test-<subject>.sh`; the runner auto-discovers `test-*.sh` in each suite.
- Start each file with `#!/usr/bin/env bash` and `set -euo pipefail`.
- Source the shared library: `source "${BASH_SOURCE[0]%/*}/../lib/testlib.sh"`.
- Use `ok "<msg>"` for a passing assertion and `bad "<msg>" "<detail>"` for a failure.
- Tests must be host-independent (no network, no installed tools) unless placed in `tests/integration/`.
- Exercise the real shipped script via its documented override seam (env var or
  flag pointed at a mktemp sandbox) - never copy the script into a fixture.

`tests/lib/testlib.sh` provides `ok`/`bad` and the summary/exit trap.

## Pull requests

Explain the motivation, state changed paths, describe rollback, and include test
output. Keep commits focused and do not include generated credentials,
machine-local configuration, or unrelated formatting.
