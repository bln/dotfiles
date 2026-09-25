#!/usr/bin/env bash
# Clear RTK token-savings history and recall stats.
#
# Delegates entirely to `rtk gain --reset --yes`; RTK owns its own data dir
# with no filesystem seam for external surgery.
#
# Usage:
#   scripts/reset-rtk.sh              # clear stats
#   scripts/reset-rtk.sh --dry-run    # show what would be cleared
set -euo pipefail

dry_run="${USAGE_DRY_RUN:-false}"
for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) dry_run=true ;;
    -h|--help)
      echo "usage: reset-rtk.sh [--dry-run]" >&2
      echo "  Clears RTK token-savings history and recall stats." >&2
      exit 0
      ;;
    *) echo "ERROR: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

rtk_cmd="${RTK_CMD:-rtk}"
if ! command -v "$rtk_cmd" >/dev/null 2>&1; then
  echo "warning: '$rtk_cmd' not found; nothing to clear"
  exit 0
fi

if [ "$dry_run" = "true" ]; then
  echo "DRY RUN: would run: $rtk_cmd gain --reset --yes"
  exit 0
fi

"$rtk_cmd" gain --reset --yes
