# dotfiles

[![CI](https://github.com/bln/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/bln/dotfiles/actions/workflows/ci.yml)

A declarative macOS development environment managed by
[mise](https://mise.jdx.dev/). One command converges a fresh Mac: tools, dotfile
symlinks, macOS defaults, packages (formulae, casks, fonts, Mac App Store apps),
VS Code extensions, and a global uv-managed Python.

mise is the sole user-facing control plane. Backend identifiers such as `brew:`
and `brew-cask:` in `[bootstrap.packages]` are mise resource keys, not a direct
Homebrew workflow. There is no Brewfile.

## Quick start

```sh
git clone <repo-url> ~/dotfiles
~/dotfiles/install.sh
exec zsh -l
```

`install.sh` installs mise, trusts the repo configs, runs
`mise bootstrap --yes`, then prompts for a machine-local git identity. Preview
first with `mise bootstrap --dry-run`. Run `install.sh --help` for options.

## Design principles

1. **One interface.** Use mise to install, update, inspect, and verify the
   machine. Never call a backend package manager directly.
2. **Declarative state.** `home/.config/mise/config.toml` describes the host.
   `mise.toml` defines repository tasks. Edit the source, then apply.
3. **Safe re-runs.** Bootstrap and setup tasks are idempotent.
4. **Explicit ownership.** Linked files are owned by the repo; shared files use
   include or copy-once; secrets are generated locally.
5. **Local secrets stay local.** Identity and credentials are never committed.

## Layout

```text
dotfiles/
├── install.sh                  # fresh-machine bootstrap (one-shot converge)
├── wipe.sh                     # safe removal of repository-owned state
├── mise.toml                   # repo-local tasks: verify, test, bootstrap, update
├── AGENTS.md                   # working rules for agents and humans
├── CLAUDE.md                   # includes AGENTS.md for Claude Code
├── LICENSE
├── .github/
│   ├── workflows/ci.yml        # CI: lint + test + bootstrap plan
│   ├── dependabot.yml
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── ISSUE_TEMPLATE/
├── scripts/
│   ├── apply-vscode-extensions.sh
│   ├── check-git-identity.sh
│   ├── check-vscode-settings.sh
│   ├── lint-shell.sh
│   └── reset-codex.sh
├── tasks/
│   └── setup/
│       └── git-identity        # prompted machine-local git identity
├── tests/
│   ├── run.sh                  # test harness (suite selection supported)
│   ├── lib/testlib.sh          # assertion helpers + sandbox management
│   ├── unit/                   # script-level tests via env-var seams
│   ├── static/                 # config format, structural, and secret checks
│   ├── integration/            # real mise + sandboxed shell startup
│   └── verify/                 # host-only behavioral checks (macOS, not CI)
├── docs/
│   └── ARCHITECTURE.md         # design rationale + package policy
└── home/                       # payload symlinked into $HOME by mise dotfiles
    ├── .zshenv
    ├── .agents/                # AGENTS.md + skills, shared across agent CLIs
    └── .config/
        ├── mise/config.toml    # THE source of truth: tools, packages, defaults
        ├── mise/mise.lock
        ├── git/                # config + global ignore (identity is machine-local)
        ├── zsh/                # .zshrc, .zprofile
        ├── nvim/init.lua
        ├── ghostty/config
        ├── gitui/
        ├── vscode/             # settings.json (extensions declared in mise [tools])
        ├── starship.toml
        ├── npm/npmrc
        └── uv/uv.toml
```

## Source of truth

| Layer | Source | Apply |
|---|---|---|
| Tools (node, uv) | `home/.config/mise/config.toml` `[tools]` | `mise install` |
| Packages (formulae, casks, fonts, MAS apps) | `home/.config/mise/config.toml` `[bootstrap.packages]` | `mise bootstrap packages apply` |
| Dotfile symlinks | `home/` + `[dotfiles]` table | `mise dotfiles apply` |
| macOS defaults | `[bootstrap.macos.*]` | `mise bootstrap macos defaults apply` |
| VS Code extensions | `config.toml` `[tools]` `vscode-ext:*` | `bash scripts/apply-vscode-extensions.sh` |
| Environment and aliases | `[env]` and `[shell_alias]` | `mise activate zsh` |
| Git identity | machine-local prompt (untracked) | `mise run setup:git-identity` |

## Adding software

1. **Versioned portable tool** (mise registry or GitHub/npm/cargo backend):
   add to `[tools]` in `home/.config/mise/config.toml`, then `mise install`.
2. **Native host package or macOS app**: add to `[bootstrap.packages]`, then
   `mise bootstrap packages apply`.
3. **Stateful setup** (symlinks, includes, generated config): create an
   idempotent file task under `tasks/`.
4. **Dev-only dependency** (shellcheck, etc.): add to `mise.toml` `[tools]`.

See `docs/ARCHITECTURE.md` for the full backend preference order and package policy.

### Managing VS Code extensions

Extensions are declared in `home/.config/mise/config.toml` `[tools]` as
`vscode-ext:<id>` entries (a no-op mise backend plugin makes the keys legal):

```toml
"vscode-ext:esbenp.prettier-vscode" = "latest"
```

- **Add / remove**: edit the `vscode-ext:*` entries, then run
  `bash scripts/apply-vscode-extensions.sh` (or `dot run update`).
- **Sync behavior**: the script installs declared-but-missing extensions (so an
  extension you deleted in the VS Code UI is reinstalled). Run `dot run update`
  to also upgrade all installed extensions via `code --update-extensions`.
- **Prune** (extensions installed but not declared, e.g. added via the VS Code
  UI): warned by default, not removed. Pass `--prune` (or
  `VSCODE_EXTENSIONS_PRUNE=true`) to uninstall them. `dot run update` prunes.
- Find an extension's ID with `code --list-extensions`.

## Configuration ownership

The repo owns some files outright and shares others with the tools that write
them. See "Configuration ownership strategies" in `docs/ARCHITECTURE.md` for the
symlink / include / copy-once / generate breakdown.

## Common commands

```sh
mise -C ~/dotfiles tasks              # list the public task interface
mise -C ~/dotfiles run test           # host-independent repository tests
mise -C ~/dotfiles run verify         # repository + installed-machine checks
mise -C ~/dotfiles run update         # upgrade tools, packages, dotfiles
mise -C ~/dotfiles run bootstrap      # finish post-bootstrap setup (idempotent)
mise bootstrap status                 # show declared machine-state drift
mise bootstrap --dry-run              # preview bootstrap without applying
```

The `dot` alias expands to `mise -C "${DOTFILES_DIR:-$HOME/dotfiles}"`, so
`dot run verify` works from any directory.

## Testing and CI

`mise run test` (from the repo root, or `dot run test` anywhere) runs the
host-independent suites - static, unit, integration - which is exactly what CI
runs. `mise run verify` additionally runs the host-only behavioral checks
(tools on PATH, plugins loaded) and checks mise health, declared-state drift,
git identity, and the VS Code settings link on a converged macOS host. See
CONTRIBUTING.md for the suites and how to add a test.

## Wipe

`wipe.sh` defaults to a dry run. With `--apply` it removes everything:
dotfile symlinks, generated local config, VS Code extensions, mise tools,
uv cache, and implodes mise. Does not uninstall Homebrew.

```sh
~/dotfiles/wipe.sh           # dry run: preview removals
~/dotfiles/wipe.sh --apply   # execute the removals
```

It does **not** revert macOS system defaults (dock, finder, keyboard) - defaults
write records no prior value, so there is nothing to restore.

## Contributing

See `CONTRIBUTING.md` for where changes belong, code rules, and testing. Run
`mise run test` before opening a pull request. Report security issues privately
per `SECURITY.md`.

## License

See `LICENSE`.
