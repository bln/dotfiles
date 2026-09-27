#!/usr/bin/env bash
# Shared path-resolution helper. Source this file; do not execute it directly.
#
# resolve_phys PATH
#   Physically resolves symlinks. If PATH does not exist, resolves its deepest
#   existing ancestor and re-appends the missing tail, so a target under a
#   symlinked parent (e.g. macOS mktemp's /var -> /private/var) is judged by its
#   real location rather than the unresolved literal.
#   Avoids a leading "//" when the deepest existing ancestor is root.
resolve_phys() {
  local p="$1" tail=""
  while [ -n "$p" ] && [ "$p" != "/" ] && [ ! -d "$p" ]; do
    tail="/$(basename "$p")$tail"
    p="$(dirname "$p")"
  done
  if [ -d "$p" ]; then
    local base
    base="$( cd "$p" && pwd -P )"
    if [ "$base" = "/" ]; then
      printf '%s\n' "$tail"
    else
      printf '%s%s\n' "$base" "$tail"
    fi
  else
    printf '%s\n' "$1"
  fi
}
