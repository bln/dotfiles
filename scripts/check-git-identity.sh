#!/usr/bin/env bash
# Assert machine-local git identity resolves (useConfigOnly blocks commits without it).
set -euo pipefail

# Seam: identity paths derive from $HOME, so tests override HOME to a sandbox.
# config sets user.useConfigOnly=true, so a missing identity silently blocks
# every commit ("unable to auto-detect email"). The remote-routed config selects
# identity-work for github.tools.sap and identity-personal everywhere else, so a
# half-configured pair (common after an interrupted setup:git-identity) leaves
# work repos unable to commit while personal looks fine. Validate BOTH.
# bootstrap/dotfiles status don't cover these (machine-local, untracked).
personal="$HOME/.config/git/identity-personal"
work="$HOME/.config/git/identity-work"

check_identity() {  # check_identity <file> <label>
  local file="$1" label="$2" name email
  if [ ! -f "$file" ]; then
    echo "ERROR: $file missing - $label commits will fail under useConfigOnly." >&2
    echo "  Fix: mise run setup:git-identity" >&2
    return 1
  fi
  name="$(git config --file "$file" user.name || true)"
  email="$(git config --file "$file" user.email || true)"
  if [ -z "$name" ] || [ -z "$email" ]; then
    echo "ERROR: $file is missing user.name or user.email." >&2
    echo "  Fix: mise run setup:git-identity --force (rewrites both files)" >&2
    return 1
  fi
  echo "OK: $label git identity resolves ($name <$email>)."
  return 0
}

rc=0
check_identity "$personal" "personal (github.com)" || rc=1
check_identity "$work" "work (github.tools.sap)" || rc=1
exit "$rc"
