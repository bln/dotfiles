# dotfiles

Small macOS dotfiles repository managed by mise.

Mise owns the complete workstation setup:

- standalone mise installation
- language runtimes and command-line tools
- the Git host package and Homebrew-compatible casks/fonts
- dotfiles
- macOS preferences

Host packages use mise's direct `brew:` and `brew-cask:` backends with the
canonical `/opt/homebrew` prefix.

## Install

Clone the repository into a stable location and run:

```sh
./install.sh
```

The installer:

1. Installs standalone mise under `~/.local/bin` if needed.
2. Trusts the repository's root `mise.toml`.
3. Runs the locked `mise bootstrap` using the checked-in `mise.lock`.
4. Installs `brew:git` through mise's bootstrap package manager.
5. Installs the remaining command-line tools as mise tools.
6. Installs casks and fonts through mise's `brew-cask` manager.
7. Deploys `home/` through mise dotfiles.
8. Applies the macOS preferences declared in `mise.toml`.

The casks are installed under `~/Applications` so the setup works without
requiring administrator access to `/Applications`.

The installer does not manage credentials, sessions, caches, or application
databases.

## Ownership

| Concern | Source | Apply |
|---|---|---|
| mise configuration and tool pins | `mise.toml` and `mise.lock` | `mise bootstrap` |
| Language runtimes and CLI tools | `[tools]` in `mise.toml` | `mise bootstrap` |
| Git host package | `"brew:git"` in `[bootstrap.packages]` | `mise bootstrap` |
| Casks and fonts | `"brew-cask:<token>"` in `[bootstrap.packages]` | `mise bootstrap` |
| Dotfiles | `home/` and `[dotfiles]` in `mise.toml` | `mise bootstrap` |
| macOS preferences | `[bootstrap.macos.*]` in `mise.toml` | `mise bootstrap` |

The checked-in `mise.lock` pins the resolved tool versions, checksums, and
artifact URLs for macOS arm64 (and the generated entries for other supported
platforms). Refresh it deliberately when upgrading tools:

```sh
mise lock --global --bump
```

The config's `[tool_config].locked = true` policy and the installer's
`--locked` flag prevent fallback resolution for tools; a missing platform entry
fails instead of making another GitHub resolution request.

`--global` is required because the canonical root configuration is also
symlinked into mise's global configuration path.

The root `mise.toml` is also deployed to `~/.config/mise/config.toml`, so the
same configuration is available to mise outside the repository checkout.

`symlink-each` keeps the directory structure in the user's home while managed
files link back to the repository. Only files tracked by Git are deployed.

## Layout

```text
dotfiles/
├── mise.toml
├── mise.lock
├── install.sh
├── README.md
├── AGENTS.md
└── home/
    ├── .zprofile
    ├── .zshrc
    ├── .npmrc
    ├── .vimrc
    ├── .config/
    │   ├── git/
    │   │   ├── config
    │   │   └── ignore
    │   ├── ghostty/
    │   └── uv/uv.toml
    ├── .agents/skills/
    ├── .claude/
    ├── .codex/
    └── .pi/agent/
```

Agent tools use their documented native locations:

```text
~/.agents/skills
~/.claude
~/.codex
~/.pi/agent
```

## Daily maintenance

Preview the complete machine state:

```sh
mise bootstrap --dry-run
```

Apply the declared state:

```sh
mise bootstrap
```

Upgrade mise-managed tools and their checked-in pins:

```sh
mise lock --global --bump
mise bootstrap
```

Upgrade the declared host formula and casks through mise:

```sh
mise bootstrap packages upgrade --manager brew
mise bootstrap packages upgrade --manager brew-cask
```

Check for drift without changing anything:

```sh
mise bootstrap status --missing
mise dot status --missing
mise doctor
```

Review package cleanup before applying it. Package pruning is machine-wide:

```sh
mise bootstrap packages prune --manager brew --dry-run
mise bootstrap packages prune --manager brew-cask --dry-run
```

Update the standalone mise binary separately:

```sh
mise self-update
```

## Git identity

Identity is machine-local. The tracked Git config, global ignore file, and
identity files all live under `~/.config/git/`; create the identity files
referenced by `~/.config/git/config`:

```sh
mkdir -p ~/.config/git
git config --file ~/.config/git/identity-personal user.name "Your Name"
git config --file ~/.config/git/identity-personal user.email "you@example.com"
git config --file ~/.config/git/identity-work user.name "Your Work Name"
git config --file ~/.config/git/identity-work user.email "you@company.example"
chmod 600 ~/.config/git/identity-*
```

The work identity is selected for `github.tools.sap`; other repositories use
the personal identity.
