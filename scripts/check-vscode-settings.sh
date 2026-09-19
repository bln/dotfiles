#!/usr/bin/env bash
# Flag when the live VS Code settings.json has drifted from the repo copy.
set -euo pipefail

# Seams: live/repo paths are overridable so tests can point them at a sandbox;
# the no-override defaults keep production behavior unchanged.
live="${VSCODE_SETTINGS_LIVE:-$HOME/Library/Application Support/Code/User/settings.json}"
repo="${VSCODE_SETTINGS_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/home/.config/vscode/settings.json}"

# settings.json is managed in copy mode (mise dotfiles), because VS Code
# rewrites it in place and would orphan a symlink. The trade-off is drift: the
# live file and the repo copy diverge whenever VS Code writes settings. Detect
# that and point at the resync path instead of failing silently.
if [ ! -e "$live" ]; then
  echo "WARNING: $live is missing - run 'mise dotfiles apply' to seed it from the repo." >&2
elif [ -L "$live" ]; then
  echo "ERROR: $live is a symlink; settings.json is managed in copy mode now." >&2
  echo "  Fix: rm the link, then 'mise dotfiles apply' to seed a real copy." >&2
  exit 1
elif ! cmp -s "$live" "$repo"; then
  echo "WARNING: live VS Code settings.json differs from the repo copy." >&2
  echo "  Pull app-written changes back:  mise dotfiles add --changed" >&2
  echo "  Or push the repo copy out:      mise dotfiles apply" >&2
else
  echo "OK: VS Code settings.json matches the repo copy."
fi
