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

1. `install.sh` installs mise, then `mise bootstrap --from` clones/reuses and
   trusts the repo and runs `mise bootstrap --yes`.
2. Declarative resources (tools, packages, dotfiles, macOS defaults) converge.
3. The `bootstrap` task performs application-specific setup (VS Code extensions, uv python).
4. `test` validates repository behavior (host-independent, runs in CI).
5. `verify` checks both repository behavior and installed-machine state.
6. `update` refreshes all managed layers (this is the re-converge path).
7. `teardown` removes repository-owned state (safe-by-default, dry-run first).

## Configuration ownership strategies

The strategy for how each config file is installed depends on who writes it:

| Who writes it | Strategy | Examples |
|---|---|---|
| Only the repo | **Symlink** - edit in repo, change is live immediately | zsh, starship, nvim, ghostty, git ignore |
| Repo + tool | **Include** - the repo file pulls in machine-local files | git config (includes untracked identity files) |
| Mostly the tool | **Copy once** - repo file seeds it, then tool owns it | VS Code settings (if symlink breaks) |
| Machine-specific | **Generate** - task prompts for local input, writes untracked files | git identity |

VS Code extensions are declared as `[tools]` entries under a no-op local backend
plugin (`vscode-ext:<id>` in `config.toml`), so the extension set lives in machine
state alongside tools. The plugin (`home/.config/mise/plugins/vscode-ext`) only
makes the keys legal; `scripts/apply-vscode-extensions.sh` reads them back
(`mise ls -c --json`) and drives `code` to install missing and prune undeclared
(`--prune`, opt-in). `mise run update` runs `code --update-extensions` to upgrade
installed extensions. The plugin's `BackendInstall` hook can later grow into a real
installer without changing how extensions are declared.

Never symlink a file that a tool rewrites. `git config --global` in particular
writes through a symlink and would put machine-local values in the repo.

## Package policy

mise is the single interface for declaring and installing packages. Native
package managers (Homebrew, npm, pip) exist as backends behind mise resource
keys but are never invoked directly by scripts, tasks, or CI. `config.toml` +
`mise.lock` are the sole manifest - there is no Brewfile.

Where new software goes, in preference order:

1. **Versioned portable tool** (mise registry, or GitHub/npm/cargo backend):
   `[tools]` in `home/.config/mise/config.toml`, then `mise install`.
2. **Native host package or macOS app**: `[bootstrap.packages]` (using `brew:`,
   `brew-cask:`, or `mas:` keys), then `mise bootstrap packages apply`.
3. **Stateful setup** (symlinks, generated config): an idempotent file task under `tasks/`.
4. **Dev-only dependency** (shellcheck, etc.): `[tools]` in the repo `mise.toml`.

Exceptions to the no-direct-backend rule:

- `install.sh` installs mise itself (and Homebrew if a mise backend needs it).
  This is the only bootstrapping exception.
- `.zshrc` may reference Homebrew plugin paths but must detect the prefix
  dynamically, never hard-code `/opt/homebrew`.
- `scripts/teardown-*.sh` may reference package-manager state for cleanup.

Enforced by the test suite: `tests/static/test-config-shape.sh` checks every
package key carries a known backend prefix (`brew:`, `brew-cask:`, `mas:`, ...),
`tests/static/test-lint.sh` runs shellcheck across all scripts, and the
host-only `tests/verify/test-tools-on-path.sh` proves the `.zshrc` brew-prefix
detection resolves at runtime rather than hard-coding `/opt/homebrew`.
