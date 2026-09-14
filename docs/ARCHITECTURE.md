# Architecture

## Control plane

mise is the only user-facing machine and package management interface. Native
package managers (Homebrew) exist behind mise package resources but are never
invoked directly by scripts, tasks, or CI workflows.

## Two mise files, one clear boundary

| File | Scope | Owns |
|---|---|---|
| `home/.config/mise/config.toml` | **Machine state** | Tool versions, package resources, macOS defaults, dotfile mappings, environment variables, shell aliases, bootstrap hooks |
| `mise.toml` | **Repository workflow** | Development tasks (test, lint, verify, update, bootstrap), task discovery paths |

Development-only tools belong in the repository `mise.toml`. Workstation-wide
tools and applications belong in the global config.

## Sources of truth

- `home/.config/mise/config.toml` + `mise.lock`: desired machine state.
- `home/`: repository-owned `$HOME` content (symlinked by mise dotfiles).
- `tasks/setup/`: idempotent generators for machine-local state.
- `scripts/`: operational checks and helpers.
- `tests/`: repository correctness validation.

## Lifecycle

1. `install.sh` installs mise, trusts configs, runs `mise bootstrap --yes`.
2. Declarative resources (tools, packages, dotfiles, macOS defaults) converge.
3. The `bootstrap` task performs application-specific setup (VS Code extensions, uv python).
4. `test` validates repository behavior (host-independent, runs in CI).
5. `verify` checks both repository behavior and installed-machine state.
6. `update` refreshes all managed layers.
7. `wipe.sh` removes repository-owned state (safe-by-default, dry-run first).

## Configuration ownership strategies

The strategy for how each config file is installed depends on who writes it:

| Who writes it | Strategy | Examples |
|---|---|---|
| Only the repo | **Symlink** - edit in repo, change is live immediately | zsh, starship, nvim, ghostty, git ignore |
| Repo + tool | **Include** - one line in a machine-local file pulls in the repo file | git config (includes config.local) |
| Mostly the tool | **Copy once** - repo file seeds it, then tool owns it | VS Code settings (if symlink breaks) |
| Machine-specific | **Generate** - task renders from template with local input | git identity, pi agent config |

Never symlink a file that a tool rewrites. `git config --global` in particular
writes through a symlink and would put machine-local values in the repo.
