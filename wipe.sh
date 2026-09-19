#!/usr/bin/env bash
# Remove all repository-owned state from this machine.
#
# Safe by default: without --apply, prints what would be removed.
# With --apply: removes dotfile symlinks, generated local config, VS Code
# extensions, mise tools, uv cache, and implodes mise.
#
# Does NOT uninstall Homebrew itself (it may predate this repo).
# Does NOT revert macOS system defaults (dock/finder/keyboard) - defaults
# write records no prior value, so there is nothing to restore.
set -euo pipefail

REPO="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
APPLY=false

bold() { printf "\033[1m%s\033[0m\n" "$1"; }
warn() { printf "WARNING: %s\n" "$1" >&2; }
die()  { printf "ERROR: %s\n" "$1" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Usage: wipe.sh [--apply]

Without --apply: dry run, prints what would be removed.
With    --apply: removes dotfile symlinks, generated local config, VS Code
                 extensions, mise tools and packages, uv cache, and implodes
                 mise. Does NOT uninstall Homebrew.
USAGE
}

# Guard: refuse to rm -rf anything that is not strictly under $HOME.
safe_under_home() {
  local path="$1"
  [ -n "$path" ] && [ "$path" != "/" ] && [ "$path" != "$HOME" ] && \
    case "$path" in "$HOME/"*) return 0 ;; esac
  return 1
}

# Returns: 0 = acted (removed or would-remove), 1 = refused (not under HOME),
#          2 = no-op (path does not exist).
safe_remove() {
  local path="$1"
  if ! safe_under_home "$path"; then
    warn "refusing to remove path outside HOME: $path"
    return 1
  fi
  if [ ! -e "$path" ] && [ ! -L "$path" ]; then
    return 2
  fi
  if [ "$APPLY" = true ]; then
    rm -rf "$path"
    printf '  removed: %s\n' "$path"
  else
    printf '  DRY RUN: would remove %s\n' "$path"
  fi
}

# Increment removed/skipped based on safe_remove's exit code.
# safe_remove exits 0=acted, 1=refused, 2=no-op(not found).
# The || true prevents set -e from aborting on the non-zero exits.
tally_remove() {
  local path="$1"
  local rc
  safe_remove "$path" || rc=$?
  rc="${rc:-0}"
  case "$rc" in
    0) removed=$((removed + 1)) ;;
    1) skipped=$((skipped + 1)) ;;
  esac
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply) APPLY=true ;;
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
  "$HOME/.config/git/identity-play"
do
  tally_remove "$path"
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
        tally_remove "$target"
        ;;
      *)
        printf '  SKIP: %s is a symlink but not owned by this repo\n' "$target"
        skipped=$((skipped + 1))
        ;;
    esac
  fi
done < <(find "$REPO/home" -type f 2>/dev/null || true)

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
# Extensions are declared as `vscode-ext:<id>` tool entries in mise config;
# derive the list the same way apply-vscode-extensions.sh does.
if command -v code >/dev/null 2>&1 && command -v mise >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  while IFS= read -r ext; do
    [ -n "$ext" ] || continue
    if [ "$APPLY" = true ]; then
      code --uninstall-extension "$ext" 2>/dev/null || true
    else
      printf '  DRY RUN: would uninstall extension %s\n' "$ext"
    fi
  done < <(mise -C "$REPO" ls -c --json 2>/dev/null \
    | jq -r 'keys[] | select(startswith("vscode-ext:")) | ltrimstr("vscode-ext:")')
else
  warn "code, mise, or jq not found; skipping extension removal"
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
  tally_remove "$path"
done

echo
bold "== WIPE $([ "$APPLY" = true ] && echo "COMPLETE" || echo "PREVIEW") =="
if [ "$APPLY" = true ]; then
  echo "  Done. Open a fresh terminal and run:"
  echo "    $REPO/install.sh"
  echo "    exec zsh -l"
else
  echo "  No changes made. Re-run with --apply after reviewing this plan."
fi

exit 0
