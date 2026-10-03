# dotfiles

Small macOS setup managed by Homebrew, GNU Stow, and mise.

## Install

Clone the repository and run:

```sh
./install.sh
```

The installer:

1. Installs Homebrew if needed.
2. Installs the declared Homebrew dependencies from `home/Brewfile`.
3. Links `home/` into `$HOME` with GNU Stow.
4. Installs the Node and uv versions declared in mise.
5. Applies the macOS preferences in `macos.sh`.

The casks are installed under `~/Applications` so the setup works without
requiring administrator access to `/Applications`.

Stow links `home/Brewfile` to `~/Brewfile`, and the shell exports
`HOMEBREW_BUNDLE_FILE` so plain `brew bundle` commands use it from any directory.

The installer does not manage credentials, sessions, caches, or application
databases.

## Ownership

| Concern | Source | Apply |
|---|---|---|
| Homebrew software | `home/Brewfile` | `brew bundle` |
| Language runtimes | `home/.config/mise/config.toml` | `mise install` |
| Dotfiles | `home/` | `stow --dir . --target "$HOME" --no-folding --restow home` |
| macOS preferences | `macos.sh` | `./macos.sh` |

Mise is used like a lightweight asdf: it manages Node and uv, not general command-line tools or applications.

## Layout

```text
dotfiles/
├── install.sh
├── macos.sh
└── home/
    ├── Brewfile
    ├── .zprofile
    ├── .zshrc
    ├── .gitconfig
    ├── .npmrc
    ├── .config/
    │   ├── ghostty/
    │   ├── git/ignore
    │   ├── mise/config.toml
    │   ├── nvim/
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

From the repository root:

```sh
brew update && brew upgrade
brew bundle
mise upgrade
stow --dir . --target "$HOME" --no-folding --restow home
```

Check the declared Homebrew state without changing anything:

```sh
brew bundle check
```

To inspect packages that are no longer declared, use Homebrew directly:

```sh
brew bundle cleanup
```

Review the output before choosing any destructive cleanup option.

## Git identity

Identity is machine-local. Create the files referenced by `.gitconfig`:

```sh
mkdir -p ~/.config/git
git config --file ~/.config/git/identity-personal user.name "Your Name"
git config --file ~/.config/git/identity-personal user.email "you@example.com"
git config --file ~/.config/git/identity-work user.name "Your Work Name"
git config --file ~/.config/git/identity-work user.email "you@company.example"
chmod 600 ~/.config/git/identity-*
```

The work identity is selected for `github.tools.sap`; other repositories use the personal identity.
