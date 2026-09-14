#!/usr/bin/env bash
# Remove repository-owned state from this machine.
#
# Safe by default: without --apply, prints what would be removed.
# Without --full, removes only dotfile symlinks and generated local config.
# With --full, also unapplies mise dotfiles, uninstalls mise-managed packages
# and tools, and removes uv cache state.
#
# Does NOT revert macOS system defaults (dock/finder/keyboard) written at
# install - defaults write records no prior value, so there is nothing to restore.
set -euo pipefail

REPO="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
APPLY=false
FULL=false

bold() { printf "\033[1m%s\033[0m\n" "$1"; }
warn() { printf "WARNING: %s\n" "$1" >&2; }
die()  { printf "ERROR: %s\n" "$1" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Usage: wipe.sh [--apply] [--full]

Without --apply: dry run, prints what would be removed.
With    --apply: executes the removals.

Without --full:  removes only repository-owned symlinks and generated local
                 config (git identity, pi agent config).
With    --full:  also unapplies mise dotfiles, uninstalls mise-managed
                 packages and tools, removes uv cache, and implodes mise.
                 Does NOT uninstall Homebrew itself (it may predate this repo).
USAGE
}

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
    warn "refusing to remove path outside HOME: $path"
    return 1
  fi
  if [ "$APPLY" = true ]; then
    if [ -e "$path" ] || [ -L "$path" ]; then
      rm -rf "$path"
      printf '  removed: %s\n' "$path"
    fi
  else
    if [ -e "$path" ] || [ -L "$path" ]; then
      printf '  DRY RUN: would remove %s\n' "$path"
    fi
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply) APPLY=true ;;
    --full)  FULL=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
  shift
done

if [ "$APPLY" = false ]; then
  bold "== DRY RUN: previewing removals (pass --apply to execute) =="
  echo
fi

removed=0
skipped=0

bold "== 1: remove machine-local generated config =="
for path in \
  "$HOME/.config/git/config.local" \
  "$HOME/.config/git/identity-play" \
  "$HOME/.pi/agent/models.json" \
  "$HOME/.pi/agent/settings.json"
do
  safe_remove "$path" && removed=$((removed + 1)) || skipped=$((skipped + 1))
done

bold "== 2: remove repository-owned dotfile symlinks =="
# Walk home/ to find all files the repo would symlink, and remove only those
# that are actually symlinks pointing at our repo.
while IFS= read -r source; do
  relative="${source#"$REPO/home/"}"
  target="$HOME/$relative"
  if [ -L "$target" ]; then
    # Verify the symlink points at our repo before removing
    link_dest="$(readlink "$target" 2>/dev/null || true)"
    case "$link_dest" in
      "$REPO/"*|"$HOME/dotfiles/"*)
        safe_remove "$target" && removed=$((removed + 1)) || skipped=$((skipped + 1))
        ;;
      *)
        printf '  SKIP: %s is a symlink but not owned by this repo\n' "$target"
        skipped=$((skipped + 1))
        ;;
    esac
  fi
done < <(find "$REPO/home" -type f 2>/dev/null || true)

if [ "$FULL" = true ]; then
  bold "== 3: unapply mise-managed dotfiles =="
  export PATH="$HOME/.local/bin:$PATH"
  if command -v mise >/dev/null 2>&1; then
    if [ "$APPLY" = true ]; then
      mise bootstrap dotfiles unapply --yes
    else
      mise bootstrap dotfiles unapply --dry-run --yes
    fi
  else
    warn "mise not found; skipping dotfiles unapply"
    skipped=$((skipped + 1))
  fi

  bold "== 4: remove VS Code extensions =="
  extensions_manifest="$REPO/home/.config/vscode/extensions.txt"
  if command -v code >/dev/null 2>&1 && [ -f "$extensions_manifest" ]; then
    while IFS= read -r line; do
      line="${line%%#*}"
      line="${line// /}"
      [ -n "$line" ] || continue
      if [ "$APPLY" = true ]; then
        code --uninstall-extension "$line" 2>/dev/null || true
      else
        printf '  DRY RUN: would uninstall extension %s\n' "$line"
      fi
    done < "$extensions_manifest"
  else
    warn "code not found or extensions manifest missing; skipping"
    skipped=$((skipped + 1))
  fi

  bold "== 5: remove mise tools and mise itself =="
  if command -v mise >/dev/null 2>&1; then
    if [ "$APPLY" = true ]; then
      mise uninstall --all --yes || true
      mise implode --yes --config || true
    else
      mise uninstall --all --dry-run || true
      mise implode --dry-run --config || true
    fi
  else
    warn "mise not found; skipping mise cleanup"
    skipped=$((skipped + 1))
  fi

  bold "== 6: remove uv cache state =="
  for path in \
    "$HOME/.local/share/uv" \
    "$HOME/.cache/uv"
  do
    safe_remove "$path" && removed=$((removed + 1)) || skipped=$((skipped + 1))
  done
fi

echo
bold "== WIPE $([ "$APPLY" = true ] && echo "COMPLETE" || echo "PREVIEW") =="
if [ "$APPLY" = true ]; then
  echo "  Done. Open a fresh terminal and run:"
  echo "    $REPO/install.sh"
  echo "    exec zsh -l"
else
  echo "  No changes made. Re-run with --apply after reviewing this plan."
  [ "$FULL" = false ] && echo "  Add --full to also remove mise tools, packages, and uv state."
fi
