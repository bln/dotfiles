# Personal dotfiles

This repository is the source of truth for one macOS Apple Silicon workstation.
Mise owns the managed tools, packages, macOS preferences, and dotfiles. Credentials,
sessions, caches, databases, and other machine-local application state remain outside
the repository.

## Install

```sh
git clone https://github.com/bln/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The installer installs mise, installs the managed tools, applies macOS settings,
and deploys the files under `home/`. It uses the repository's checked-in global
mise configuration during the initial bootstrap, before that configuration has
been linked into `$HOME`.

After installation, create your local Git identity files from the examples:

```sh
cp -n ~/.config/git/identity-personal.example ~/.config/git/identity-personal
cp -n ~/.config/git/identity-work.example ~/.config/git/identity-work
chmod 600 ~/.config/git/identity-personal ~/.config/git/identity-work
```

Edit the `name` and `email` values in both files before committing. The examples
are blank, and `user.useConfigOnly` makes Git refuse to guess an identity. The
personal identity is the default; the work identity applies to repositories
with `github.tools.sap` remotes. `cp -n` preserves identity files that already
exist. Mise deploys the examples but does not create or manage identity contents.

## Ownership

| Source | Responsibility |
| --- | --- |
| `home/.config/mise/config.toml` | Global machine settings, tools, packages, macOS bootstrap declarations, and dotfile deployment |
| `home/.config/mise/mise.lock` | Locked global tool artifacts for macOS Apple Silicon |
| `home/` | Files deployed into their native `$HOME` locations with `symlink-each` |
| `home/.config/git/identity-*.example` | Examples for machine-local Git identity files |
| `install.sh` | Initial mise bootstrap |
| `uninstall.sh` | Explicit mise-native teardown |

The global mise configuration and lockfile are part of `home/`. The `home`
dotfile group deploys them to:

```text
~/.config/mise/config.toml
~/.config/mise/mise.lock
```

The global config resolves the dotfile source root from the canonical path of
`home/.config/mise/config.toml`. That points to `home/` during initial bootstrap
and continues to work when the config file is deployed as a symlink under
`$HOME`.

## Configuration layout

The `home/` tree mirrors the target home directory:

- `home/.zshenv` establishes the XDG configuration, cache, data, and state roots,
  sets `ZDOTDIR=$HOME/.config/zsh`, and provides the editor environment before
  other Zsh startup files run.
- `home/.config/zsh/.zprofile` and `home/.config/zsh/.zshrc` contain the login
  and interactive shell behavior, aliases, tool initialization, history
  bindings, and the One Dark terminal palette.
- `home/.config/git/` contains Git behavior, identity examples, and the
  Conventional Commit template.
- `home/.config/nvim/init.lua` contains the plugin-free Neovim configuration.
- `home/.config/vim/vimrc` and `home/.config/vim/colors/` contain the native
  Vim configuration and the `mini-onedark` and `mini-gruvbox` colorschemes.
- `home/.config/gitui/theme.ron` contains the GitUI One Dark color overrides.
- `home/.config/npm/npmrc` contains the npm user configuration;
  `NPM_CONFIG_USERCONFIG` points npm to this XDG path.
- `home/.config/ghostty/`, `home/.config/starship.toml`,
  `home/.config/zed/`, and `home/Library/Application Support/Code/User/`
  contain the remaining managed application configurations.
- `home/.local/bin/` intentionally contains no repository-owned helper scripts; it
  remains available for machine-local tools such as mise.
- `home/.agents/`, `home/.claude/`, `home/.codex/`, and `home/.pi/` contain
  repository-owned agent instructions and extensions only.

Configuration stays in native locations. The repository does not add alternate
configuration homes or track generated application state.

## Editors and keybindings

Vim and Neovim are the command-line editors and Zed is the primary graphical
editor. VS Code remains available as a secondary graphical editor.
Mise-activated shells, Git, and the GitHub CLI use `nvim`; Vim and Neovim are
plugin-free and use the shared `mini-onedark` palette by default. Vim also
includes the selectable `mini-gruvbox` colorscheme. Zed uses Vim mode and the
One Dark theme. VS Code extensions are intentionally not declared here and
remain managed by VS Code.

The Zed settings and keymap live in the native macOS location under
`home/.config/zed/` and are deployed to `~/.config/zed/`.

The VS Code user settings and keybindings live in the native macOS location under
`home/Library/Application Support/Code/User/` and are deployed to
`~/Library/Application Support/Code/User/`.

The Zsh root shim is intentionally retained: `~/.zshenv` must set `ZDOTDIR`
before Zsh can read `~/.config/zsh/.zprofile` and `~/.config/zsh/.zshrc`. Shell
history and completion dumps live under `~/.local/state/zsh` and `~/.cache/zsh`.

Read the owning configuration before changing an editor binding. Prefer native
behavior and keep the Vim and VS Code keymaps deliberately small.

### Shell shortcuts

- `l`, `ll`, `la`, `lla`, and `tree` - eza directory listings.
- `bat` - OneHalfDark theme with line numbers, change markers, and header.
- `Ctrl-T` - fzf file picker with bat previews.
- `Alt-C` - fzf directory picker.
- `Up` and `Down` - native prefix-aware Zsh history search.
- `z` - zoxide directory jumping.

## Maintenance

Run these commands from the repository root:

```sh
mise bootstrap --dry-run
mise bootstrap status --missing
mise dot status --missing
mise doctor
mise run update
```

The global `mise run update` task can be run from any directory. It ensures
mise-managed tools are installed, upgrades the configured tools and packages,
applies the repository dotfiles, and updates mise itself. The dotfile group
resolves its source from the deployed global config's canonical path.

The coding agents `claude-code`, `codex`, and `pi`, along with eza, GitUI,
Delta, Neovim, Zed, and VS Code, are managed through mise. Vim remains
available as the native macOS command-line editor.

The repository does not install custom commands under `~/.local/bin`. That
machine-local directory remains on `PATH` for tools installed by mise.

The GitHub Actions configuration runs the shell, Git, GitHub CLI, Mise, and
dry-run bootstrap checks on macOS.

For a deliberate dotfile deployment that overwrites conflicting files:

```sh
mise dot apply --force --yes
```

Use the global context when locking or installing tools declared by the global
configuration:

```sh
mise lock --global
mise install
```

The global lockfile is `home/.config/mise/mise.lock`. A root `mise.lock` is only
needed if this repository later declares project-specific tools.

Upgrade managed tools with `mise upgrade`. Refresh locked artifacts only when
intended with `mise lock --global --bump`.

## Boundaries

Do not track credentials, secret values, agent sessions, caches, application
state, databases, generated output, or temporary editor state. Keep private Git
identity files in their native machine-local locations. Mise manages only their
`0600` permissions; their contents are not tracked and they survive dotfile
unapply. Run `./uninstall.sh --yes` only after backing up anything else that must
survive. It un-applies this repository's dotfiles, prunes mise-owned Homebrew
resources, removes mise-managed tool versions, and implodes mise configuration
and state. It does not restore removed user files or macOS preferences.
