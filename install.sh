#!/usr/bin/env bash
set -euo pipefail

die() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

REPO="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$REPO/home/.config/mise/config.toml"

[ -f "$CONFIG" ] || die "$CONFIG not found."

export PATH="$HOME/.local/bin:$PATH"

if ! command -v mise >/dev/null 2>&1; then
  curl -fsSL https://mise.run | MISE_VERSION="2026.9.5" sh
fi

command -v mise >/dev/null 2>&1 || die "mise not found after install attempt."

export MISE_GLOBAL_CONFIG_FILE="$CONFIG"

mise trust "$CONFIG"
mise trust "$REPO/mise.toml"

if [ -d "$REPO/tasks" ]; then
  mise trust "$REPO/tasks"
fi

mise bootstrap --yes --force-dotfiles

[ -f "$HOME/.config/git/config.local" ] || mise run setup:git-identity
