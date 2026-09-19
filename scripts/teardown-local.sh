#!/usr/bin/env bash
# Teardown step 3: remove machine-local generated files and uv cache state.
#
# The only raw-`rm` step, so it carries the safety guard: refuse to remove
# anything not strictly under HOME. Safe by default: without --apply (or
# APPLY=true) it dry-runs.
#
# Test seam: HOME is honored (tests point it at a sandbox), and safe_under_home
# gates every removal against it.
set -euo pipefail

APPLY="${APPLY:-false}"
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=true ;;
    *) printf 'unknown argument: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

# Guard: refuse to rm -rf anything that is not strictly under $HOME.
safe_under_home() {
  local path="$1"
  [ -n "$path" ] && [ "$path" != "/" ] && [ "$path" != "$HOME" ] && \
    case "$path" in "$HOME/"*) return 0 ;; esac
  return 1
}

safe_remove() {
  local path="$1"
  if ! safe_under_home "$path"; then
    printf 'WARNING: refusing to remove path outside HOME: %s\n' "$path" >&2
    return 1
  fi
  if [ ! -e "$path" ] && [ ! -L "$path" ]; then
    return 0
  fi
  if [ "$APPLY" = true ]; then
    rm -rf "$path"
    printf '  removed: %s\n' "$path"
  else
    printf '  DRY RUN: would remove %s\n' "$path"
  fi
}

for path in \
  "$HOME/.config/git/identity-personal" \
  "$HOME/.config/git/identity-work" \
  "$HOME/.local/share/uv" \
  "$HOME/.cache/uv"
do
  safe_remove "$path" || true
done
