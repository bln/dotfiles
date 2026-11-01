# Personal Dotfiles

Dotfiles and workstation configuration for **macOS on Apple Silicon**.

Mise manages tools, packages, macOS preferences, and dotfile deployment. Credentials, sessions, caches, databases, and application state are machine-local and are not tracked.

## Install

```sh
git clone https://github.com/bln/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

`install.sh` installs Mise and bootstraps the workstation. Files under `home/` mirror their target paths under `$HOME`.

Create the machine-local Git identity files:

```sh
touch ~/.config/git/identity-personal
touch ~/.config/git/identity-work
```

Fill them with the following content

```ini
name = user-name
email = user-email
```

## Editors

- **Neovim**: primary terminal editor
- **Zed**: primary GUI editor
- **VS Code**: secondary GUI editor

Modify keybindings only in the owning configuration. Prefer native behavior and minimal custom mappings.

### Shell

- `l`, `ll`, `la`, `lla`, `tree`: `eza` listings
- `bat`: OneHalfDark with line numbers, change markers, and headers
- `Ctrl-T`: `fzf` file picker with `bat` preview
- `Alt-C`: `fzf` directory picker
- `Up` / `Down`: prefix-aware Zsh history
- `z`: `zoxide` navigation

## Maintenance

Run from the repository root:

```sh
mise bootstrap --dry-run
mise bootstrap status --missing
mise dot status --missing
mise doctor
mise run update
```

Force dotfile deployment:

```sh
mise dot apply --force --yes
```

Manage global tool locks:

```sh
mise lock --global
mise install
```

Update locked artifacts explicitly:

```sh
mise lock --global --bump
```

GitHub Actions validates shell, Git, GitHub CLI, Mise, and dry-run bootstrap behavior on macOS.

## Uninstall

```sh
./uninstall.sh --yes
```

This unapplies dotfiles, prunes Mise-owned Homebrew resources, removes Mise-managed tool versions, and removes Mise configuration and state.

**It does not restore deleted user files or macOS preferences.**
