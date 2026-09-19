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

if [ "$APPLY" = true ]; then
  mise bootstrap dotfiles unapply --yes
else
  mise bootstrap dotfiles unapply --dry-run --yes
fi
