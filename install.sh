#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# install.sh - Bootstrap or update this dotfiles workstation via mise
#
# Usage:
#   ./install.sh            Full bootstrap (first-time setup)
#   ./install.sh --update   Update existing installation
#   ./install.sh --help     Show this help message
# -------------------------------------------------------------------

die() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

usage() {
  printf 'Usage: %s [--update | --help]\n\n' "$(basename "$0")"
  printf '  (no args)   Full bootstrap: install mise, trust configs, converge everything\n'
  printf '  --update    Update an existing installation (tools, packages, dotfiles)\n'
  printf '  --help      Show this help message\n'
  exit 0
}

MODE="bootstrap"
for arg in "$@"; do
  case "$arg" in
    --help|-h)  usage ;;
    --update)   MODE="update" ;;
    *)          die "Unknown argument: $arg. Use --help for usage." ;;
  esac
done

REPO="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$REPO/home/.config/mise/config.toml"

[ -f "$CONFIG" ] || die "$CONFIG not found."

export PATH="$HOME/.local/bin:$PATH"

if ! command -v mise >/dev/null 2>&1; then
  curl -fsSL https://mise.run | MISE_VERSION="2026.9.7" sh
fi

command -v mise >/dev/null 2>&1 || die "mise not found after install attempt."

export MISE_GLOBAL_CONFIG_FILE="$CONFIG"

mise trust "$CONFIG"
mise trust "$REPO/mise.toml"

if [ -d "$REPO/tasks" ]; then
  mise trust "$REPO/tasks"
fi

if [ "$MODE" = "update" ]; then
  printf '==> Updating tools and packages...\n'
  mise install
  mise run update 2>/dev/null || printf '(no update task defined, skipping)\n'
  printf '==> Update complete.\n'
else
  mise bootstrap --yes --force-dotfiles
  [ -f "$HOME/.config/git/config.local" ] || mise run setup:git-identity
fi
