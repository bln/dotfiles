#!/usr/bin/env bash
# Bootstrap a fresh macOS machine from this dotfiles repo.
# On subsequent runs it converges to the declared state.
set -euo pipefail

die() { printf "ERROR: %s\n" "$1" >&2; exit 1; }

DRY_RUN=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=true ;;
    -h|--help)
      cat <<'EOF'
Usage: ~/dotfiles/install.sh [--dry-run]

Bootstrap a fresh macOS machine from this dotfiles checkout.
  --dry-run  Preview what mise bootstrap would change without applying it.
             Calls 'mise bootstrap --dry-run'; no changes are made.
EOF
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
  shift
done

REPO="$(cd "$(dirname "$0")" && pwd)"
MIN_MISE_VERSION="2026.9.5"
CONFIG="$REPO/home/.config/mise/config.toml"

[ -f "$CONFIG" ] || die "$CONFIG not found. Run install.sh from the dotfiles checkout."

# ── install mise ────────────────────────────────────────────
if ! command -v mise >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/mise" ]; then
  if [ "$DRY_RUN" = "true" ]; then
    echo "DRY RUN: would install mise $MIN_MISE_VERSION"
  else
    # Install mise pinned to MIN_MISE_VERSION
    MISE_VERSION="$MIN_MISE_VERSION" curl -fsSL https://mise.run | sh
  fi
fi
export PATH="$HOME/.local/bin:$PATH"

[ "$DRY_RUN" = "true" ] || command -v mise >/dev/null 2>&1 || \
  die "mise not found after install attempt. Check network access."

# ── point mise at this repo's config ────────────────────────────────────
# On a fresh machine ~/.config/mise/config.toml does not exist yet.
# MISE_GLOBAL_CONFIG_FILE bridges the gap: every mise call in this session
# reads the repo config. Phase 10 of mise bootstrap (dotfiles apply) creates
# the permanent symlink, so future shells need no override.
export MISE_GLOBAL_CONFIG_FILE="$CONFIG"

if [ "$DRY_RUN" != "true" ]; then
  mise trust "$CONFIG"
  mise trust "$REPO/mise.toml"
  [ -d "$REPO/tasks" ] && mise trust "$REPO/tasks"
fi

# ── bootstrap ─────────────────────────────────────────────────────
# min_version in config.toml enforces the minimum mise version and aborts
# with a clear error if mise is too old to run this config.
if [ "$DRY_RUN" = "true" ]; then
  mise bootstrap --dry-run
else
  mise bootstrap --yes
fi

# ── git identity (interactive, must run last) ─────────────────────────────
if [ "$DRY_RUN" != "true" ]; then
  [ -f "$HOME/.config/git/config.local" ] || mise run setup:git-identity
  echo
  echo "Done. Open a new shell:  exec zsh -l"
fi
