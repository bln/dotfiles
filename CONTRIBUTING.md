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
| Machine identity or secrets | Generated ignored files, never tracked values |

See `docs/ARCHITECTURE.md` and `docs/PACKAGE-POLICY.md`.

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
Scopes: `zsh`, `git`, `nvim`, `ghostty`, `vscode`, `mise`, `ci`, `wipe`, etc.

## Tests

Add or update tests for every behavior change. Name files `test-<subject>.sh`
and place them in the appropriate `static/`, `unit/`, `integration/`, or
`contract/` suite.

```sh
mise run test          # host-independent repository tests
mise run verify        # additionally checks installed machine state (macOS)
```

## Pull requests

Explain the motivation, state changed paths, describe rollback, and include test
output. Keep commits focused and do not include generated credentials,
machine-local configuration, or unrelated formatting.
