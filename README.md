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

The installer installs mise, prompts for private Git identity values, installs the
managed tools, applies macOS settings, and deploys the files under `home/`. It
uses the repository's checked-in global mise configuration during the initial
bootstrap, before that configuration has been linked into `$HOME`.

## Ownership

| Source | Responsibility |
| --- | --- |
| `home/.config/mise/config.toml` | Global machine settings, tools, packages, and macOS bootstrap declarations |
| `home/.config/mise/mise.lock` | Locked global tool artifacts for macOS Apple Silicon |
| `mise.toml` | Repository project configuration for dotfiles and templates |
| `home/` | Files deployed into their native `$HOME` locations with `symlink-each` |
| `templates/git/` | Private rendered Git identity files |
| `install.sh` | Initial mise bootstrap |
| `uninstall.sh` | Explicit mise-native teardown |

The global mise configuration and lockfile are part of `home/`, so the existing
whole-home dotfile declaration deploys them to:

```text
~/.config/mise/config.toml
~/.config/mise/mise.lock
```

The root `mise.toml` remains the project configuration for repository-relative
dotfile sources. It does not declare machine-wide tools.

## Configuration layout

The `home/` tree mirrors the target home directory:

- `home/.zshenv` establishes the XDG configuration, cache, data, and state roots,
  sets `ZDOTDIR=$HOME/.config/zsh`, and provides the editor environment before
  other Zsh startup files run.
- `home/.config/zsh/.zprofile` and `home/.config/zsh/.zshrc` contain the login
  and interactive shell behavior, aliases, tool initialization, history
  bindings, and the One Dark terminal palette.
- `home/.config/git/` contains Git behavior and the Conventional Commit template.
- `home/.config/nvim/init.lua` contains the plugin-free Neovim configuration.
- `home/.config/gh/config.yml` contains GitHub CLI defaults and aliases;
  authentication remains in GitHub's native machine-local state.
- `home/.config/vim/vimrc` and `home/.config/vim/colors/` contain the native
  Vim configuration and the `mini-onedark` and `mini-gruvbox` colorschemes.
- `home/.config/gitui/theme.ron` contains the GitUI One Dark color overrides.
- `home/.config/npm/npmrc` contains the npm user configuration;
  `NPM_CONFIG_USERCONFIG` points npm to this XDG path.
- `home/.config/ghostty/`, `home/.config/starship.toml`,
  `home/.config/zed/`,
  `home/Library/Application Support/Code/User/`, and `home/.config/bat/` contain
  the remaining managed application configurations.
- `home/.local/bin/git-code-stats` and `home/.local/bin/git-get` contain the
  repository helper commands.
- `home/.agents/`, `home/.claude/`, `home/.codex/`, and `home/.pi/` contain
  repository-owned agent instructions and extensions only.

Configuration stays in native locations. The repository does not add alternate
configuration homes or track generated application state.

## Editors and keybindings

Vim and Neovim are the command-line editors and Zed is the primary graphical
editor. VS Code remains available as a secondary graphical editor. The shell,
Git, and GitHub CLI use `nvim`; Vim and Neovim are plugin-free and use the
shared `mini-onedark` palette by default. Vim also includes the selectable
`mini-gruvbox` colorscheme. Zed uses Vim mode and the One Dark theme. VS Code
extensions are intentionally not declared here and remain managed by VS Code.

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
- `Ctrl-T` - fzf file picker with bat previews.
- `Alt-C` - fzf directory picker.
- `Up` and `Down` - native prefix-aware Zsh history search.
- `z` - zoxide directory jumping.

## Maintenance

Run these commands from the repository root:

```sh
mise bootstrap --dry-run
mise bootstrap --prompt-secrets
mise bootstrap status --missing
mise dot status --missing
mise doctor
mise run update
```

The global `mise run update` task can be run from any directory. It ensures
mise-managed tools are installed, upgrades the configured tools and packages,
applies the repository dotfiles, and updates mise itself. It uses the canonical
`~/dotfiles` checkout when applying the repository configuration.

The coding agents `claude-code`, `codex`, and `pi`, along with eza, GitUI,
Delta, Neovim, Zed, and VS Code, are managed through mise. Vim remains
available as the native macOS command-line editor.

The restored helper commands can be used from any Git repository:

~~~sh
git code-stats [today|week|month|all]
git get github.com/user/repo
~~~

The GitHub Actions configuration runs the same shell, Git, GitHub CLI, Mise,
and dry-run bootstrap checks on macOS.

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
identity files in their native machine-local locations. Run `./uninstall.sh --yes` only
after backing up anything that must survive. It un-applies this repository's dotfiles, prunes
mise-owned Homebrew resources, removes mise-managed tool versions, and implodes mise
configuration and state. It does not restore removed user files or macOS preferences.
