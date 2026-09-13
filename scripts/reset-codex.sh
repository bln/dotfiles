#!/usr/bin/env bash
# Clear Codex CLI and ChatGPT app state while retaining configuration.
#
# Usage:
#   scripts/reset-codex.sh              # clear session state
#   scripts/reset-codex.sh --dry-run    # show what would be removed
set -euo pipefail

# Target dir is the seam: tests point CODEX_HOME at a mktemp sandbox; the
# no-override default keeps production behavior unchanged.
codex_home="${CODEX_HOME:-$HOME/.codex}"

# Accept --dry-run flag; also honour USAGE_DRY_RUN for test compatibility.
dry_run="${USAGE_DRY_RUN:-false}"
for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) dry_run=true ;;
    -h|--help)
      echo "usage: reset-codex.sh [--dry-run]" >&2
      echo "  Clears Codex CLI and ChatGPT app state while retaining configuration." >&2
      exit 0
      ;;
    *) echo "ERROR: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

[ -d "$codex_home" ] || { echo "nothing to clear: $codex_home does not exist"; exit 0; }

if [ "$dry_run" = "true" ]; then
  echo "DRY RUN: would clear session state under $codex_home (keeping config/auth):"
  find "$codex_home" -mindepth 1 -maxdepth 1 \
    ! -name "auth.json" \
    ! -name "config.toml" \
    ! -name "AGENTS.md" \
    ! -name "AGENTS.override.md" \
    ! -name "rules" \
    ! -name "skills" \
    -print
  exit 0
fi

# Delete everything under codex_home EXCEPT the config/auth we keep. Getting the
# exclusion list wrong is data loss (auth.json, config.toml), so this is the part
# a test must cover.
find "$codex_home" -mindepth 1 -maxdepth 1 \
  ! -name "auth.json" \
  ! -name "config.toml" \
  ! -name "AGENTS.md" \
  ! -name "AGENTS.override.md" \
  ! -name "rules" \
  ! -name "skills" \
  -exec rm -rf -- {} +

echo "cleared Codex session state under $codex_home (kept config/auth)"
