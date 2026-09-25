#!/usr/bin/env bash
# Clear Claude Code session state while retaining configuration.
#
# Delegates project/task/history state to `claude project purge --all`, then
# removes the remaining session dirs that the CLI does not touch.
#
# Usage:
#   scripts/reset-claude.sh              # clear session state
#   scripts/reset-claude.sh --dry-run    # show what would be removed
set -euo pipefail

# CLAUDE_CONFIG_DIR is the real Claude Code env var; the script inherits it
# directly. Tests set CLAUDE_CONFIG_DIR to a mktemp sandbox; the no-override
# default keeps production behavior unchanged.
claude_home="${CLAUDE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/claude}"

dry_run="${USAGE_DRY_RUN:-false}"
for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) dry_run=true ;;
    -h|--help)
      echo "usage: reset-claude.sh [--dry-run]" >&2
      echo "  Clears Claude Code session state while retaining configuration." >&2
      exit 0
      ;;
    *) echo "ERROR: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# shellcheck source=scripts/lib/resolve-phys.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/resolve-phys.sh"
safe_claude_home() {
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
if ! safe_claude_home "$claude_home"; then
  echo "ERROR: refusing to operate on unsafe CLAUDE_CONFIG_DIR: '$claude_home'" >&2
  echo "  It must be a non-root path at least two levels below /." >&2
  exit 2
fi

[ -d "$claude_home" ] || { echo "nothing to clear: $claude_home does not exist"; exit 0; }

# Dirs removed by direct file ops (not covered by `claude project purge`).
# projects/, tasks/, file-history/, history.jsonl, and .claude.json project
# entries are handled by the CLI call below.
session_dirs=(sessions cache paste-cache session-env shell-snapshots plans)

if [ "$dry_run" = "true" ]; then
  echo "DRY RUN: would run: claude project purge --all --yes (projects, tasks, file-history, history.jsonl, .claude.json entries)"
  echo "DRY RUN: would clear session dirs under $claude_home (keeping config/auth):"
  for d in "${session_dirs[@]}"; do
    [ -e "$claude_home/$d" ] && echo "  $claude_home/$d"
  done
  exit 0
fi

# Delegate project/task/history state to the CLI. CLAUDE_CONFIG_DIR is already
# set in the environment (inherited by the child), so `claude project purge`
# operates on the same dir this script is clearing.
if command -v claude >/dev/null 2>&1; then
  purge_output=""
  purge_rc=0
  if purge_output="$(claude project purge --all --yes 2>&1)"; then
    if [ -n "$purge_output" ]; then
      printf '%s\n' "$purge_output"
    fi
  else
    purge_rc=$?
    case "$purge_output" in
      *"No Claude Code project state found"*)
        echo "nothing to purge: no Claude Code project state found"
        ;;
      *)
        if [ -n "$purge_output" ]; then
          printf '%s\n' "$purge_output" >&2
        fi
        exit "$purge_rc"
        ;;
    esac
  fi
else
  echo "warning: 'claude' not found; skipping project purge (projects/, tasks/, file-history/, history.jsonl)"
fi

# Remove remaining session dirs.
for d in "${session_dirs[@]}"; do
  [ -e "$claude_home/$d" ] && rm -rf -- "${claude_home:?}/$d"
done

echo "cleared Claude session state under $claude_home (kept config/auth)"
