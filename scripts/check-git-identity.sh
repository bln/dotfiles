#!/usr/bin/env bash
# Assert machine-local git identity resolves (useConfigOnly blocks commits without it).
set -euo pipefail

# Seam: identity path derives from $HOME, so tests override HOME to a sandbox.
# config sets user.useConfigOnly=true, so a missing identity-personal silently
# blocks every commit ("unable to auto-detect email"). bootstrap/dotfiles status
# don't cover it (it's machine-local, untracked), so assert it here.
local="$HOME/.config/git/identity-personal"

if [ ! -f "$local" ]; then
  echo "ERROR: $local missing - commits will fail under useConfigOnly." >&2
  echo "  Fix: mise run setup:git-identity" >&2
  exit 1
fi

name="$(git config --file "$local" user.name || true)"
email="$(git config --file "$local" user.email || true)"
if [ -z "$name" ] || [ -z "$email" ]; then
  echo "ERROR: $local is missing user.name or user.email." >&2
  echo "  Fix: mise run setup:git-identity (delete identity-personal first to re-run)" >&2
  exit 1
fi

echo "OK: git identity resolves ($name <$email>)."
