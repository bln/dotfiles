#!/usr/bin/env bash
# Clear Pi agent session state while retaining configuration.
#
# Usage:
#   scripts/reset-pi.sh              # clear session state
#   scripts/reset-pi.sh --dry-run    # show what would be removed
set -euo pipefail

# PI_CODING_AGENT_DIR is Pi's supported agent-root override. Keep PI_HOME as a
# compatibility/test seam when the supported variable is not set.
if [ -n "${PI_CODING_AGENT_DIR:-}" ]; then
  pi_agent="$PI_CODING_AGENT_DIR"
  pi_target_label="PI_CODING_AGENT_DIR"
else
  pi_home="${PI_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/pi}"
  pi_agent="${pi_home}/agent"
  pi_target_label="PI_HOME"
fi

dry_run="${USAGE_DRY_RUN:-false}"
for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) dry_run=true ;;
    -h|--help)
      echo "usage: reset-pi.sh [--dry-run]" >&2
      echo "  Clears Pi agent session state while retaining configuration." >&2
      exit 0
      ;;
    *) echo "ERROR: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# shellcheck source=scripts/lib/resolve-phys.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/resolve-phys.sh"
safe_pi_agent() {
  local raw="$1" phys depth
  [ -n "$raw" ] || return 1
  [ "$raw" != "/" ] || return 1
  phys="$(resolve_phys "$raw")"
  [ -n "$phys" ] && [ "$phys" != "/" ] && [ "$phys" != "$HOME" ] || return 1
  case "$phys/" in
    /bin/*|/sbin/*|/usr/*|/etc/*|/var/*|/private/etc/*|/private/var/*|/System/*|/Library/*|/Applications/*|/opt/*|/dev/*|/proc/*|/sys/*|/boot/*|/root/*)
      case "$phys/" in /private/var/folders/*) : ;; *) return 1 ;; esac ;;
  esac
  depth="$(printf '%s' "${phys#/}" | tr -cd '/' | wc -c)"
  [ "$depth" -ge 1 ] || return 1
  return 0
}
if ! safe_pi_agent "$pi_agent"; then
  echo "ERROR: refusing to operate on unsafe $pi_target_label: '$pi_agent'" >&2
  echo "  It must be a non-root path at least two levels below /." >&2
  exit 2
fi

[ -d "$pi_agent" ] || { echo "nothing to clear: $pi_agent does not exist"; exit 0; }

# Enumerate top-level entries to remove under agent/ (everything except
# config/auth and managed extensions).
session_entries() {
  find "$pi_agent" -mindepth 1 -maxdepth 1 \
    ! -name "auth.json" \
    ! -name "AGENTS.md" \
    ! -name "settings.json" \
    ! -name "models.json" \
    ! -name "models-store.json" \
    ! -name "extensions" \
    "$@"
}

if [ "$dry_run" = "true" ]; then
  echo "DRY RUN: would clear session state under $pi_agent (keeping config/auth/extensions):"
  session_entries -print
  exit 0
fi

session_entries -exec rm -rf -- {} +

echo "cleared Pi session state under $pi_agent (kept config/auth/extensions)"
