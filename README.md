# dotfiles

Personal macOS workstation configuration for Apple Silicon. . The `home/` directory mirrors `$HOME`.

## Install

```sh
git clone https://github.com/bln/dotfiles.git ~/dotfiles
cd ~/dotfiles

curl -fsSL --proto '=https' https://mise.run | sh
MISE_CONFIG_DIR="$PWD/home/.config/mise" "$HOME/.local/bin/mise" bootstrap --yes --force-dotfiles
```

## Repository layout

- `home/` mirrors `$HOME`; mise deploys tracked files as relative symlinks.
- `patches/` contains settings merged into existing Claude, Pi, and RTK configuration files.
- `mise.toml` defines dotfile groups and the `update`, `cleanup`, and optional `boostrap` tasks.
- `home/.config/mise/config.toml` defines tools, packages, apps, and macOS preferences.
- `uninstall.sh` removes the mise-managed setup.

## Uninstall

```sh
./uninstall.sh --yes
```

## CI

GitHub Actions runs on macOS 26. It checks shell syntax, mise configuration and dotfile deployment, and Git whitespace.
