#!/usr/bin/env bash
# Teardown step 1: remove repository-owned dotfile symlinks via mise.
#
# Delegates the whole symlink walk to `mise bootstrap dotfiles unapply` - it
# knows exactly which links the [dotfiles] table owns, so we don't re-derive it.
#
# Safe by default: without --apply (or APPLY=true) it dry-runs.
set -euo pipefail

APPLY="${APPLY:-false}"
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=true ;;
    *) printf 'unknown argument: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

export PATH="$HOME/.local/bin:$PATH"
if ! command -v mise >/dev/null 2>&1; then
  printf 'WARNING: mise not found; skipping dotfiles unapply\n' >&2
  exit 0
fi

# Point mise at the checkout's machine config explicitly. The [dotfiles] table
# there is the only record of which links mise owns; deriving it from the repo
# (via this script's own path) rather than the ~/.config/mise/config.toml
# symlink keeps unapply correct after that symlink is removed and regardless of
# cwd - symmetric with install.sh. DOTFILES_DIR overrides for tests.
repo="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
config="$repo/home/.config/mise/config.toml"
if [ -f "$config" ]; then
  export MISE_GLOBAL_CONFIG_FILE="$config"
fi

if [ "$APPLY" = true ]; then
  mise -C "$repo" bootstrap dotfiles unapply --yes
else
  mise -C "$repo" bootstrap dotfiles unapply --dry-run --yes
fi
