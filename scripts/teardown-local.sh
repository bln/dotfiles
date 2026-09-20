#!/usr/bin/env bash
# Teardown step 3: remove machine-local generated files and uv cache state.
#
# The only raw-`rm` step, so it carries the safety guard: refuse to remove
# anything not strictly under HOME. Safe by default: without --apply (or
# APPLY=true) it dry-runs.
#
# Test seam: HOME is honored (tests point it at a sandbox), and safe_under_home
# gates every removal against it. The file is also sourceable (BASH_SOURCE guard
# at the bottom): tests source it to exercise the REAL safe_under_home rather
# than a copy.
set -euo pipefail

APPLY="${APPLY:-false}"

# Guard: refuse to rm -rf anything that is not strictly under $HOME. Resolve
# symlinks physically first so an intermediate symlink cannot point a
# nominally-under-$HOME path at a target outside it. Resolves the deepest
# existing ancestor when the path itself is absent (nothing to remove then).
resolve_phys() {
  local p="$1" tail=""
  while [ -n "$p" ] && [ "$p" != "/" ] && [ ! -d "$p" ]; do
    tail="/$(basename "$p")$tail"
    p="$(dirname "$p")"
  done
  if [ -d "$p" ]; then
    printf '%s%s\n' "$( cd "$p" && pwd -P )" "$tail"
  else
    printf '%s\n' "$1"
  fi
}
safe_under_home() {
  local path="$1" phys home_phys
  [ -n "$path" ] && [ "$path" != "/" ] && [ "$path" != "$HOME" ] || return 1
  phys="$(resolve_phys "$path")"
  home_phys="$(resolve_phys "$HOME")"
  [ -n "$phys" ] && [ "$phys" != "/" ] && [ "$phys" != "$home_phys" ] || return 1
  case "$phys" in "$home_phys/"*) return 0 ;; esac
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

main() {
  for path in \
    "$HOME/.config/git/identity-personal" \
    "$HOME/.config/git/identity-work" \
    "$HOME/.local/share/uv" \
    "$HOME/.cache/uv"
  do
    safe_remove "$path" || true
  done
}

# Execute only when run directly; sourcing (tests) just loads the functions.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  for arg in "$@"; do
    case "$arg" in
      --apply) APPLY=true ;;
      *) printf 'unknown argument: %s\n' "$arg" >&2; exit 2 ;;
    esac
  done
  main
fi
