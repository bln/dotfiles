#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# install.sh - first-run bootstrap of this dotfiles workstation via mise.
#
# Installs mise (pinned), then hands the whole converge to
# `mise bootstrap --from`: it clones (or reuses) the repo, trusts it, cd's in,
# and runs the 8-phase bootstrap - tools, packages, dotfiles, macOS defaults,
# and the repo's own `[tasks.bootstrap]` (VS Code extensions + uv python).
# Finally prompts for a machine-local git identity in the foreground.
#
# Re-converge is `mise run update` (or `dot run update`), not this script.
# -------------------------------------------------------------------

# Install the latest mise if absent. We deliberately do NOT pin a version here:
# config.toml's `min_version` is the single source of truth for the mise floor
# this repo requires, and `mise bootstrap` enforces it once the repo is cloned.
# A second pinned copy here (or in CI) would only create drift. See docs/TESTING.md.
if ! command -v mise >/dev/null 2>&1; then
  curl -fsSL https://mise.run | sh
fi
export PATH="$HOME/.local/bin:$PATH"
command -v mise >/dev/null 2>&1 || { printf 'ERROR: mise not found after install.\n' >&2; exit 1; }

# The --from URL must match the checkout's remote.origin.url exactly, or
# --from-dir reuse bails. It matches this repo's https origin.
mise bootstrap --from "https://github.com/bln/dotfiles.git" \
  ${DOTFILES_DIR:+--from-dir "$DOTFILES_DIR"} --yes --force-dotfiles

# Prompt for machine-local identity in the foreground - not a bootstrap hook,
# which would silently skip under a non-TTY stdin. curl | bash uses stdin for
# the script itself, so use the controlling terminal for the interactive task.
# The task is idempotent and prompts for whichever identity file is missing.
if [ -t 0 ]; then
  mise run setup:git-identity
elif { exec 3</dev/tty; } 2>/dev/null; then
  mise run setup:git-identity <&3
else
  printf 'ERROR: git identity setup requires an interactive terminal. Run mise run setup:git-identity from a terminal.\n' >&2
  exit 2
fi
