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
- Use `set -euo pipefail` in Bash scripts, except those that drive tools whose
  nonzero exit is a normal signal (see `scripts/vscodectl`): those use
  `set -u` with explicit `|| die` / failure handling, and adding `set -e` would
  silently break them.
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

Read `docs/TESTING.md` first - it is the contract for what this suite does and
does not test. In short: guard behavior, script logic, and data-loss paths;
never restate the config or re-test mise. Run from the repo root (or use
`dot run test` from anywhere):

```sh
mise run test          # lint + the ci tier (hermetic; what CI runs)
mise run verify        # additionally runs the host tier + machine state (macOS)
```

### Tiers

Tests are split by one question only - *does this need a converged mac?*

| Tier | Directory | Checks | Needs host state? |
|---|---|---|---|
| **ci** | `tests/ci/` | Script logic via seams, shell startup under a pty, config parse, secret + copy-tree hygiene | No (hermetic) |
| **host** | `tests/host/` | Tools+plugins resolve, install re-run idempotent, real VS Code apply/teardown | Yes (macOS host, not CI) |

The ci tier runs on every push (Linux + macOS). The host tier is wired into
`mise run verify`, never CI, and skips cleanly off-host. Do not re-introduce a
static/unit/integration split; see `docs/TESTING.md`.

### Conventions

- Name test files `test-<subject>.sh`; the runner auto-discovers `test-*.sh` in each tier.
- Source the shared library and use `ok`/`bad`/`skip`; `tests/lib/testlib.sh` owns the summary and exit trap.
- Exercise the real shipped script via its documented seam (env var or flag at a
  mktemp sandbox) - never copy the script into a fixture. If a script is hard to
  test, make it testable (add a seam, make it sourceable, extract the pure
  decision).
- Skip cleanly (do not fail) when an optional dependency is absent.
- Before adding a test, run the checklist at the end of `docs/TESTING.md`.

## Pull requests

Explain the motivation, state changed paths, describe rollback, and include test
output. Keep commits focused and do not include generated credentials,
machine-local configuration, or unrelated formatting.
