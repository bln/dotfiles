#!/usr/bin/env bash
# Clear Codex CLI and ChatGPT app state while retaining configuration.
#
# Usage:
#   scripts/reset-codex.sh              # clear session state
#   scripts/reset-codex.sh --dry-run    # show what would be removed
set -euo pipefail

# Target dir is the seam: tests point CODEX_HOME at a mktemp sandbox; the
# no-override default keeps production behavior unchanged.
codex_home="${CODEX_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/codex}"

# Parse args before the CODEX_HOME safety guard so --help/--dry-run are always
# answerable regardless of env (the guard only needs to fire before any delete,
# which happens later). Also honour USAGE_DRY_RUN for test compatibility.
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


# Guard: this script rm -rf's nearly everything under $codex_home, so a bad
# CODEX_HOME is data loss. Production only ever uses $HOME/.codex; the seam may
# point at a mktemp sandbox (NOT under $HOME), so the guard cannot require $HOME.
# Instead reject the paths that are actually catastrophic to recursively clear:
# empty, /, $HOME itself, and any shallow path (a top-level system dir like /etc,
# /usr, /var). Resolve symlinks physically first so an intermediate symlink
# cannot smuggle the real target up to one of those.
resolve_phys() {
  # Resolve symlinks physically. If the path itself does not exist yet, resolve
  # its deepest existing ancestor and re-append the missing tail, so a target
  # under a symlinked parent (e.g. macOS mktemp's /var -> /private/var) is judged
  # by its real location rather than the unresolved literal.
  local p="$1" tail=""
  while [ -n "$p" ] && [ "$p" != "/" ] && [ ! -d "$p" ]; do
    tail="/$(basename "$p")$tail"
    p="$(dirname "$p")"
  done
  if [ -d "$p" ]; then
    local base
    base="$( cd "$p" && pwd -P )"
    # base is "/" when the deepest existing ancestor is root; concatenating the
    # "/…"-prefixed tail would then yield a leading "//" that the prefix-based
    # denylist below silently fails to match. Emit the tail alone in that case.
    if [ "$base" = "/" ]; then
      printf '%s\n' "$tail"
    else
      printf '%s%s\n' "$base" "$tail"
    fi
  else
    printf '%s\n' "$1"
  fi
}
safe_codex_home() {
  local raw="$1" phys depth
  [ -n "$raw" ] || return 1
  [ "$raw" != "/" ] || return 1
  phys="$(resolve_phys "$raw")"
  [ -n "$phys" ] && [ "$phys" != "/" ] && [ "$phys" != "$HOME" ] || return 1
  # Reject known system roots and anything directly beneath them. On macOS
  # several (/etc, /var, /tmp) resolve through symlinks into /private, so match
  # the resolved form. This is a denylist of prefixes that must never be the
  # recursive-delete target regardless of depth.
  case "$phys/" in
    /bin/*|/sbin/*|/usr/*|/etc/*|/var/*|/private/etc/*|/private/var/*|/System/*|/Library/*|/Applications/*|/opt/*|/dev/*|/proc/*|/sys/*|/boot/*|/root/*)
      # /private/var/folders (macOS mktemp home) is the legitimate exception.
      case "$phys/" in /private/var/folders/*) : ;; *) return 1 ;; esac ;;
  esac
  # Require at least one segment below root so a bare top-level dir cannot slip
  # through a gap in the denylist.
  depth="$(printf '%s' "${phys#/}" | tr -cd '/' | wc -c)"
  [ "$depth" -ge 1 ] || return 1
  return 0
}
if ! safe_codex_home "$codex_home"; then
  echo "ERROR: refusing to operate on unsafe CODEX_HOME: '$codex_home'" >&2
  echo "  It must be a non-root path at least two levels below /." >&2
  exit 2
fi

[ -d "$codex_home" ] || { echo "nothing to clear: $codex_home does not exist"; exit 0; }

# Enumerate top-level entries to remove (everything except config/auth).
session_entries() {
  # Caller appends the find action: -print or -exec rm -rf -- {} +
  find "$codex_home" -mindepth 1 -maxdepth 1 \
    ! -name "auth.json" \
    ! -name "config.toml" \
    ! -name "AGENTS.md" \
    ! -name "AGENTS.override.md" \
    ! -name "rules" \
    ! -name "skills" \
    "$@"
}

if [ "$dry_run" = "true" ]; then
  echo "DRY RUN: would clear session state under $codex_home (keeping config/auth):"
  session_entries -print
  exit 0
fi

# Delete everything under codex_home EXCEPT the config/auth we keep. Getting the
# exclusion list wrong is data loss (auth.json, config.toml), so this is the part
# a test must cover.
session_entries -exec rm -rf -- {} +

echo "cleared Codex session state under $codex_home (kept config/auth)"
