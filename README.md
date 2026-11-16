# dotfiles

Personal macOS workstation configuration for Apple Silicon. The `home/` directory mirrors `$HOME`.

## Install

```sh
git clone https://github.com/bln/dotfiles.git ~/dotfiles
cd ~/dotfiles

curl -fsSL --proto '=https' https://mise.run | sh
MISE_CONFIG_DIR="$PWD/home/.config/mise" "$HOME/.local/bin/mise" bootstrap --yes --force-dotfiles
```

The global config at `home/.config/mise/config.toml` owns tools, Homebrew packages,
environment, macOS preferences, and dotfile deployment.

## Shell shortcuts

- Ctrl-R searches history (Ctrl-Y copies the selected command),
- Ctrl-T inserts file paths with bat previews
- Alt-C changes directories.
- Ctrl-/ toggles file/directory previews.
- Type `**` then Tab for fuzzy completion.

## Maintenance

```sh
mise run global:update
mise run global:cleanup
```

## Uninstall

```sh
./uninstall.sh --yes
```

Independently installed Claude, Pi, and Codex CLIs remain installed.

## CI

GitHub Actions runs on macOS 26.
